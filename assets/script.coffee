_ = require './underscore'
Backbone = require './backbone'

class Room extends Backbone.Model
  defaults:
    people: []

class RoomCollection extends Backbone.Collection
  model: Room

class User extends Backbone.Model
  defaults:
    vote: -1

  change_vote: (vote) ->
    this.save({"vote": vote})


poll_room = (roomname) ->
  $.get("api/rooms/#{roomname}",
    (data) ->
      room.set(data)
  )

room = new Room(
  self: "Joe",
  name: "My Room",
  people: []
)
console.log room.get("user")
console.log room.get("name")
console.log room.get("people")
