#!/usr/bin/env ruby

require "bundler/setup"
require "trollop"
require "sinatra/base"
require "json"
require "logger"
require "coffee-script"
require "erb"
require "stylus"

module ScrumCard
  VALID_VOTES = [1, 2, 3, 5, 8, 13].map(&:to_s) << "?"
  HEARTBEAT_SECONDS = 1
  USER_TIMEOUT_SECONDS = HEARTBEAT_SECONDS * 3
  class Error < RuntimeError; end

  # A user is per-room
  class User
    attr_reader :vote, :guid

    def initialize(guid)
      @guid = guid
      reset_vote!
      heartbeat
    end

    def expired?() Time.now > @last_heartbeat + USER_TIMEOUT_SECONDS end

    def heartbeat() @last_heartbeat = Time.now end

    def cast_vote(value)
      raise Error, "#{value} is not a valid value for a vote" unless VALID_VOTES.include? value
      @vote = value
    end

    def voted?() !!@vote end

    def reset_vote!() @vote = nil end
  end

  class Room
    attr_accessor :last_update
    attr_reader :users

    # A room must have a user to be initialized
    def initialize(username, guid, logger)
      @users = {}
      add_user username, guid
      @logger = logger
      @expiration = Time.at(Time.now + 24 * 60 * 60) # Expire after 1 day
      @last_update = Time.now
    end

    def heartbeat(username) @users[username].heartbeat end

    def expired?() Time.now > @expiration end

    # Get a view of the users and votes where the votes are hidden unless they are all cast
    def votes(current_user)
      result = {}
      @users.each do |name, user|
        if all_voted?
          result[name] = user.vote
        else
          result[name] = (name == current_user) ? (user.vote || "") : (user.vote ? "hidden" : "")
        end
      end
      result
    end

    def add_user(username, guid)
      raise Error, "User #{username} already exists." if @users.include? username
      @users[username] = User.new guid
      @last_update = Time.now
    end

    def all_voted?() @users.values.all?(&:voted?) end

    # Cast or change vote
    def cast_vote(username, value)
      raise Error, "Voting has ended." if all_voted?
      raise Error, "#{username} is not present in this room" unless @users.include? username
      @users[username].cast_vote value
      @last_update = Time.now
    end

    def remove_expired_users!
      @users.reject! do |name, user|
        if user.expired?
          @last_update = Time.now
          @logger.info "Removing expired user #{name}."
        end
        user.expired?
      end
    end

    def reset_votes!
      @users.values.each(&:reset_vote!)
      @last_update = Time.now
    end
  end

  class Server < Sinatra::Base
    set :public_folder, "public"
    attr_accessor :current_user, :current_user_guid

    LOGIN_WHITELIST = [%r[^js/], %r[^css/], %r[^login], /favicon/]

    def initialize
      super
      @logger = Logger.new STDOUT
      @logger.level = Logger::INFO
      @rooms = {}
    end

    def remove_expired_users!(room_name) @rooms[room_name].remove_expired_users! end

    # Garbage collect rooms that have persisted for a long time
    def remove_expired_rooms!
      @rooms.reject! do |name, room|
        @logger.info "Removing expired room #{name}." if room.expired?
        room.expired?
      end
    end

    def json_body() JSON.parse(request.body.read) end

    before do
      next if LOGIN_WHITELIST.any? { |route| request.path[1..-1] =~ route }
      self.current_user = request.cookies["user"]
      self.current_user_guid = request.cookies["guid"]
      unless self.current_user
        response.set_cookie "redirect_to", :value => request.url, :path => "/"
        @logger.info "Redirecting to /login"
        redirect "/login"
      end
    end

    get "/js/:filename.js" do |filename|
      asset_path = "public/#{filename}.js"
      content_type "application/javascript", :charset => "utf-8"
      if File.exists? asset_path
        File.read(asset_path)
      else
        CoffeeScript.compile(File.read("assets/#{filename}.coffee"))
      end
    end

    get "/css/:filename.css" do |filename|
      asset_path = "public/#{filename}.js"
      content_type "text/css", :charset => "utf-8"
      if File.exists? asset_path
        File.read(asset_path)
      else
        Stylus.compile(File.read("assets/#{filename}.styl"))
      end
    end

    # Main data call + heartbeat; gives room data in json
    get "/api/rooms/:name" do |room_name|
      halt 401, "No user specified" unless current_user
      room = @rooms[room_name]
      halt 400, "No room #{room_name}" unless room
      # Cleanup
      remove_expired_users! room_name
      remove_expired_rooms!

      if room.users.include? current_user
        if room.users[current_user].guid != current_user_guid
          halt 409, "There is already a user #{current_user} in the room #{room_name}."
        end
      else
        room.add_user(current_user, current_user_guid)
      end
      room.heartbeat current_user
      return 304 if params[:last_update].to_i >= room.last_update.to_i
      erb :_vote_table, :layout => false, :locals => {
          :last_update => room.last_update.to_i, :votes => room.votes(current_user),
          :current_user => current_user, :voting_complete => room.all_voted?
      }
    end

    # Get a json list of room names
    get "/api/rooms" do
      content_type :json
      @rooms.keys.to_json
    end

    # Cast a vote; the body of the POST is json-ified vote (e.g. 1 or "?")
    post "/api/rooms/:name" do |room_name|
      halt 401, "No user specified" unless current_user
      room = @rooms[room_name]
      halt 404, "Bad room #{room_name}" unless room
      unless room.users.include? current_user
        halt 404, "User #{current_user} is not in the room #{room_name}."
      end
      vote = json_body["vote"]
      begin
        room.cast_vote current_user, vote
      rescue Error => e
        halt 400, e.message
      end
      "OK"
    end

    # Generate a random ID (not a true guid, but fine for us). See
    # http://stackoverflow.com/questions/105034/how-to-create-a-guid-uuid-in-javascript
    def generateGuid
      def s4() ((1 + rand)  * 0x10000).round.to_s(16)[1..-1] end
      "#{s4()}#{s4()}#{s4()}#{s4()}"
    end

    # Set a username
    post "/login" do
      # Right now we're not tracking users server-side at all
      user = params["user"]
      if user.nil? || user.strip.empty?
        # TODO: render the login page with an error
        redirect "/login"
      end
      response.set_cookie "user", user
      response.set_cookie "guid", generateGuid
      redirect params[:redirect_to] || "/"
    end

    # Reset the votes of a room without removing users
    post "/api/rooms/:name/reset" do |room_name|
      room = @rooms[room_name]
      halt 404, "Bad room #{room_name}" unless room
      room.reset_votes!
      "OK"
    end

    # Serve the login page
    get "/login" do
      @logger.info "/login"
      erb :login
    end

    # Serve the view of a room
    get "/rooms/:name" do |room_name|
      room = @rooms[room_name]
      unless room
        room = Room.new current_user, current_user_guid, @logger
        @rooms[room_name] = room
      end
      erb :room, :locals => { :room_name => room_name, :room => room, :choices => VALID_VOTES }
    end

    # Serve a view of all the rooms
    get("/") { erb :index, :locals => { :rooms => @rooms } }
  end
end

if __FILE__ == $0
  options = Trollop::options do
    opt :host, "Hostname of the server", :default => "localhost"
    opt :port, "Port on which to listen", :default => 8080
  end

  ScrumCard::Server.run! :host => options[:host], :port => options[:port]
end
