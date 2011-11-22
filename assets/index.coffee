window.Index =
  init: ->
    # TODO(caleb) remove deprecated live() calls
    $("#newRoom").live "submit", (e) => @onNewRoomSubmit(e)

  onNewRoomSubmit: (e) ->
    e.preventDefault()
    window.open "/rooms/#{$(e.target).find("input").val()}"

$(document).ready(-> Index.init())
