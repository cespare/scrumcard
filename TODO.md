TODO
====

* Histogram
* Previous results section should indicate when it is the current result for the complete vote
* Update the Rooms view with ajax to see when other people create rooms without refreshing
* Two columns for displaying results
* Login with email; retrieve gravatars to go with the username
* Investigate long-polling options that aren't too difficult to implement and work on phones
* Hand cursor for buttons
* Bug: when the vote is revealed by someone leaving the room, the 'previous results' aren't updated.
* Bug: Sometimes voting appears to have no effect. See if we can determine why...maybe we need to retry on
  failure or something?
* Scrub debugging logging statements in the coffeescript.
* Rewrite in Golang + socket.io
* A 'show votes' button
* A 'pester everyone who hasn't voted' button.
* Bug(ish): the votes are re-hidden when someone joins the room.
