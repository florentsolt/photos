'use strict';

var path = require('path'),
    Promise = require("bluebird"),
    fs = require('fs'),
    root = path.join(__dirname, 'albums'),
    cache = {};

Promise.promisifyAll(fs);

function Album(name) {
  this.name = name;
  this.title = "title of " + name;
  this.description = "description of " + name;
  this.font = "Yellowtail";
}

Album.prototype.load = function() {
  return fs.readFileAsync(path.join(root, this.name, 'album.json'))
    .then(text => {
      this.pictures = JSON.parse(text);
      return cache[this.name] = this;
    });
};

Album.find = function(name, silent) {
  if (cache[name]) {
    return Promise.resolve(cache[name]);
  } else {
    return fs.statAsync(path.join(root, name))
      .then(stat => stat.isDirectory())
      .then(() => fs.statAsync(path.join(root, name, 'album.json')))
      .then(() => new Album(name))
      .catch((e) => {
        if (silent) {
          return false;
        } else {
          throw e;
        };
      });
  }
};

Album.all = function() {
  return fs.readdirAsync(root)
    .map(folder => Album.find(folder, true))
    .filter(album => album);
}

module.exports = Album;
