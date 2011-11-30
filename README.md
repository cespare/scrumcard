scrumcard
=========

A web app for planning poker.

Here's a screenshot:

![Screenshot](https://github.com/cespare/scrumcard/raw/master/public/screenshot.png)

Installation
------------

Make sure you have node installed. Then you should be able to run `bundle install` and then run the app
directly:

    $ ruby scrumcard_server.rb

or

    $ ruby scrumcard_server.rb --port 3456 --host 0.0.0.0

Usage
-----

This should be obvious if you visit the app in your browser (perhaps from several browsers at once). Note that
the interface is actually optimized for a mobile phone.

Caveats
-------

This software was written to be the easiest thing that would work. We have intentionally cut many corners. All
data is kept in memory on the server -- there is no persistence whatsoever. This also means that the app
cannot be run simultaneously on multiple servers without room- and user-aware load-balancing. There is also no
user authentication.

All of this is intentional and will probably never be fixed, because we don't anticipate needing to support
large numbers of people simultaneously doing sprint planning.

License
-------

Copyright (c) 2011 Caleb Spare

[MIT License](http://www.opensource.org/licenses/mit-license.php)
