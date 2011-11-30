class window.Room
  HEARTBEAT_SECONDS: 1

  constructor: (@name) ->
    console.log "creating new room: #{@name}"
    @last_update = 0
    @maybeRefreshResults()
    Util.setInterval @HEARTBEAT_SECONDS * 1000, => @maybeRefreshResults()
    $("#choices select").on "change", (e) => @onVote(e)
    $("#reset a").on "click", (e) => @onReset(e)

  # Only refresh if there have been updates.
  maybeRefreshResults: ->
    $.ajax
      type: "get"
      url: "/api/rooms/#{@name}?last_update=#{@last_update}"
      statusCode:
        200: (result) =>
          $("#votes").html result
          # Set the intensities
          for row in $("#votes tr")
            $row = $(row)
            continue if $row.is(".notVoted, .hidden")
            intensity = Number($row.attr("data-intensity"))
            # Hex #A3A3F9 ($lightBlue) -- the most intense blue we will use for the highest votes
            $row.css("background-color", "rgba(163, 163, 249, #{intensity})")
          @last_update = Number($("#votes table").attr("data-last-update"))
        409: (result) =>
          alert result.responseText
          window.location = "/"
        304: =>
          # NOTE(caleb): I'll just explicitly put this case here for completeness. This happens when the last
          # server update time is no more recent than our own recorded last update time.
          return
        # 400: => # This happens when the room is cleaned up. Take care of this later.

  onVote: (event) ->
    $.ajax
      type: "post"
      url: "/api/rooms/#{@name}"
      data: $.toJSON { vote: event.target.value }
      contentType: "application/json"
      success: => @maybeRefreshResults()

  onReset: (event) ->
    event.preventDefault()
    $.ajax
      type: "post"
      url: "/api/rooms/#{@name}/reset"
      success: => @maybeRefreshResults()
