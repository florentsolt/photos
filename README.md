What is it ?
============

* A simple sinatra webapp to display photo streams from flickr or zip files.
* Stats module included (from Flickr and Google Analytics).
* Everything stored in Redis or on the filesystems.

Why and when use it ?
=====================

* When you want to publish via your own server
* When you want to merge different photo streams in one gallery
* When only want to ask from your friends a zip file
* When you want to gather stats from Flickr and Google Analytics in one place
* When you want an optimized photo gallery, even for phones and tablets

How to install ?
================

* Install jpegtran, pngcrush and exiftools binaries, for example: `$> apt-get install libjpeg-turbo-progs libimage-exiftool-perl pngcrush`
* Install GraphicsMagick
* `$> bundle install`
* Run redis-server
* Copy `config.yml-dist` to `config.yml` and fix the file
* `$> ruby application.rb`
