window.Index =
  init: ->
    $("#newRoom form").on "submit", (e) => @onNewRoomSubmit(e)

  onNewRoomSubmit: (e) ->
    e.preventDefault()
    window.location = "/rooms/#{$(e.target).find("input").val()}"

$(document).ready(-> Index.init())
