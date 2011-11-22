class window.Room
  HEARTBEAT_SECONDS: 1

  constructor: (@name) ->
    console.log "creating new room: #{@name}"
    @last_update = 0
    @maybeRefreshResults()
    Util.setInterval @HEARTBEAT_SECONDS * 1000, => @maybeRefreshResults()

  # Only refresh if there have been updates.
  maybeRefreshResults: ->
    $.ajax
      type: "get"
      url: "/api/rooms/#{@name}?last_update=#{@last_update}"
      statusCode:
        200: (result) =>
          @last_update = result.last_update
          @refreshResults result.current_user, result.votes
        409: (result) =>
          alert result.responseText
          window.location = "/"
        304: =>
          # Note(caleb): I'll just explicitly put this case here for completeness. This happens when the last
          # server update time is no more recent than our own recorded last update time.
          return

  refreshResults: (current_user, votes) ->
    newVoteList = $("<ul></ul>")
    newVoteList.append("<li>#{user}: #{vote}</li>") for user, vote of votes
    $("#room").html newVoteList
