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
  HEARTBEAT_SECONDS = 2
  USER_TIMEOUT = HEARTBEAT_SECONDS * 2
  class Error < RuntimeError; end

  # A user is per-room
  class User
    attr_reader :vote
    def initialize
      reset_vote!
      heartbeat
    end

    def expired?
      Time.now > @last_heartbeat + USER_TIMEOUT
    end

    def heartbeat
      @last_heartbeat = Time.now
    end

    def vote(value)
      raise Error, "#{vote} is not a valid value for a vote" unless VALID_VOTES.include? vote
      @vote = vote
    end

    def voted?
      !!@vote
    end

    def reset_vote!
      @vote = nil
    end
  end

  class Room
    # A room must have a user to be initialized
    def initialize(username, logger)
      @users = {}
      add_user username
      @logger = logger
      @expiration = Time.at(Time.now + 24 * 60 * 60) # Expire after 1 day
    end

    def expired?
      Time.now > @expiration
    end

    # Get a view of the users and votes where the votes are hidden unless they are all cast
    def votes
      all_voted = @users.values.all?(&:voted?)
      result = {}
      @users.each { |name, user| result[name] = all_voted ? user.vote : nil }
      result
    end

    def users
      @users.keys
    end

    def add_user(username)
      raise Error, "User #{username} already exists." if @users.include? user
      @users[username] = User.new
    end

    # Cast or change vote
    def cast_vote(username, vote)
      raise Error, "#{username} is not present in this room" unless @users.include? username
    end

    def remove_expired_users!
      @users.reject! do |name, user|
        @logger.info "Removing expired user #{name}." if user.expired?
        user.expired?
      end
    end

    def reset_votes!
      users.each(&:reset_vote!)
    end
  end

  class Server < Sinatra::Base
    set :public, "public"

    def initialize
      super
      @logger = Logger.new STDOUT
      @logger.level = Logger::INFO
      @rooms = {}
    end

    def remove_expired_users!(room)
      @logger.info "Purging expired users from #{room}..."
      room.remove_expired_users!
      @logger.info "Done."
    end

    # Garbage collect rooms that have persisted for a long time
    def remove_expired_rooms!
      @logger.info "Removing expired rooms..."
      @rooms.reject! do |name, room|
        @logger.info "Removing expired room #{name}." if room.expired?
        room.expired?
      end
    end

    def username
      request.cookies["user"]
    end

    def json_body
      JSON.parse(request.body)
    end

    get "/" do
      erb :"/index", :locals => { :rooms => @rooms }
    end

    get "/assets/:filename.js" do
      asset_path = "assets/#{params[:filename]}.js"
      if !File.exists?(asset_path)
        asset_path = "assets/#{params[:filename]}.coffee"
        asset = CoffeeScript.compile(File.read(asset_path))
      else
        asset = File.read(asset_path)
      end
      #TODO(kle): file does not exist at all
      content_type "application/javascript", :charset => "utf-8"
      asset
    end

    get "/assets/:filename.css" do
      asset_path = "assets/#{params[:filename]}.css"
      if !File.exists?(asset_path)
        asset_path = "assets/#{params[:filename]}.styl"
        asset = Stylus.compile(File.read(asset_path))
      else
        asset = File.read(asset_path)
      end
      #TODO(kle): file does not exist at all
      content_type "text/css", :charset => "utf-8"
      asset
    end

    # Main data call + heartbeat; gives room data in json
    # Yes, we're creating rooms on a GET. We know it's janky. So sue us.
    get "/api/rooms/:name" do |room_name|
      halt 401, "No user specified" unless username
      content_type :json
      room = @rooms[room_name]
      unless room
        room = Room.new username, @logger
        @rooms[room_name] = room
      end
      # Cleanup
      remove_expired_users! room_name
      remove_expired_rooms!

      room.add_user(username) unless room.users.include? username
      { :user => username, :room => room_name, :votes => room.votes }.to_json
    end

    # Get a json list of room names
    get "/api/rooms" do
      content_type :json
      @rooms.keys.to_json
    end

    # Cast a vote; the body of the POST is json-ified vote (e.g. 1 or "?")
    post "/api/rooms/:name" do |room_name|
      halt 401, "No user specified" unless username
      room = @rooms[room_name]
      halt 404, "Bad room #{room_name}" unless room
      halt 404, "User #{username} is not in the room #{room_name}." unless room.users.include? username
      vote = json_body["vote"]
      begin
        room.cast_vote username, vote
      rescue Error => e
        halt 400, e.message
      end
      "OK"
    end

    # Set a username
    post "/login" do
      # Right now we're not tracking users server-side at all
      user = json_body["user"]
      unless user.nil? || user.strip.empty?
        # TODO: render the login page with an error
      end
      set_cookie "user", user
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
      # TODO: Render the login page.
    end

    # Serve the view of a room
    get "/rooms/:name" do |room_name|
      room = @rooms[room_name]
      if room
        # TODO: render room
      else
        # TODO: render error? Or redirect
      end
    end

    # Serve a view of all the rooms
    get "/" do
      # TODO: render main page
    end

    # A view of the whole state, for debugging
    get "/world" do
      result = ""
      @rooms.each do |room_name, room|
        result << "<h4>room_name</h4>\n"
        @room.instance_variable_get(:@users).each do |name, user|
          result << "  #{name}: #{user.vote}"
        end
      end
      result
    end
  end
end

if __FILE__ == $0
  options = Trollop::options do
    opt :host, "Hostname of the server", :default => "localhost"
    opt :port, "Port on which to listen", :default => 8080
  end

  ScrumCard::Server.run! :host => options[:host], :port => options[:port]
end
