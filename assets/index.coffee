window.Index =
  init: ->
    $("#newRoom").on "submit", (e) => @onNewRoomSubmit(e)

  onNewRoomSubmit: (e) ->
    e.preventDefault()
    window.open "/rooms/#{$(e.target).find("input").val()}"

$(document).ready(-> Index.init())
