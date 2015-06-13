What is it ?
============

* A simple sinatra webapp to display photo albums from flickr or zip files.
* Everything stored on the filesystems.

Why and when use it ?
=====================

* When you want to publish via your own server
* When you want to merge different photo sets in one album
* When only want to ask from your friends a zip file
* When you want an optimized photo gallery, even for phones and tablets

How to install ?
================

* Install jpegtran and pngcrush binaries, for example: `$> apt-get install libjpeg-turbo-progs pngcrush`
* Install GraphicsMagick
* `$> bundle install`
* Consider install `thin`, because it's faster than `webrick`
* Copy `config.yml-dist` to `config.yml` and fix the file
* `$> ruby application.rb`
