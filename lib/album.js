'use strict';

var path = require('path'),
    Promise = require("bluebird"),
    fs = require('fs'),
    root = path.join(__dirname, '..', 'albums'),
    cache = {};

Promise.promisifyAll(fs);

function Album(name) {
  this.name = name;
}

Album.prototype.load = function() {
  return fs.readFileAsync(path.join(root, this.name, 'album.json'))
    .then(text => {
      var object = JSON.parse(text);
      Object.keys(object).forEach(key => (this[key] = object[key]));
      if (this.reverse) this.pictures = this.pictures.reverse();
      cache[this.name] = this;
      return this;
    });
};

Album.find = function(name, silent) {
  if (process.env.NODE_ENV === 'production' && cache[name]) {
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
        }
      });
  }
};

Album.all = function() {
  return fs.readdirAsync(root)
    .map(folder => Album.find(folder, true))
    .filter(album => album)
    .map(album => album.load())
    .then(albums => albums.sort((a, b) => {
      // Start with the newest albums to the oldest
      // Then finished with the ones with no dates, alphabetical order
      if (a.date === undefined && b.date) {
        return 1;
      } else if (a.date && b.date === undefined) {
        return -1;
      } else if (a.date && b.date) {
        return a.date < b.date ? 1 : -1;
      } else {
        return a.name > b.name ? 1 : -1;
      }
    }));
};

Album.route = (req, res, next) => {
  var name = req.url.split('/')[1].replace('.', '');
  Album.find(name)
    .then(album => album.load())
    .then(album => {
      req.log.push("found album " + album.name);
      req.album = album;
      next();
    }).catch(() => {
      if (req.url !== '/') {
        var err = new Error('Album not found');
        err.status = 404;
        next(err);
      } else {
        next();
      }
    });
};
module.exports = Album;
