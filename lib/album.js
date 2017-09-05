'use strict';

var path = require('path'),
    _fs = require('fs'),
    util = require('util'),
    wrap = require('./wrap'),
    fs = {
      stat: util.promisify(_fs.stat),
      readFile: util.promisify(_fs.readFile),
      readdir: util.promisify(_fs.readdir)
    },
    root = path.join(__dirname, '..', 'albums'),
    inflection = require( 'inflection' ),
    cache = {};

function Album(name) {
  this.name = name;
}

Album.prototype.load = async function() {
  let object = JSON.parse(await fs.readFile(path.join(root, this.name, 'album.json')));
  Object.keys(object).forEach(key => {
    this[key] = object[key];
  });
  if (this.reverse) this.pictures = this.pictures.reverse();
  if (!this.title) {
    this.title = inflection.titleize(this.name.replace(/-|_/g, ' '));
  }
  if (!this.description) {
    if (this.dates.from === this.dates.to) {
      this.description = this.dates.from;
    } else {
      this.description = this.dates.from + ' / ' + this.dates.to;
    }
  }
  if (!this.font) {
    this.font = require('../config').font;
  }
  return (cache[this.name] = this);
};

Album.find = async function(name) {
  if (process.env.NODE_ENV === 'production' && cache[name]) {
    return cache[name];
  } else {
    try {
      let dStat = await fs.stat(path.join(root, name));
      let fStat = await fs.stat(path.join(root, name, 'album.json'));
      if (dStat.isDirectory() && fStat.isFile()) {
        return new Album(name);
      }
    } catch (e) {
      // Ignore
    }
  }
  return false;
};

Album.all = async function() {
  let albums = [];
  for (let folder of await fs.readdir(root)) {
    let album = await Album.find(folder);
    if (album) {
      albums.push(await album.load());
    }
  }

  albums = albums.sort((a, b) => {
    // Start with the newest albums to the oldest
    // Then finished with the ones with no dates, alphabetical order
    if (a.dates.to === undefined && b.dates.to) {
      return 1;
    } else if (a.dates.to && b.dates.to === undefined) {
      return -1;
    } else if (a.dates.to && b.dates.to) {
      return a.dates.to < b.dates.to ? 1 : -1;
    } else {
      return a.name > b.name ? 1 : -1;
    }
  });

  return albums;
};

Album.route = wrap(async function(req, res, next) {
  let name = req.url.split('/')[1].replace('.', '');
  let album = await Album.find(name);
  if (album) {
    req.album = await album.load();
    req.log.push("found album " + req.album.name);
  } else if (req.url !== '/') {
    let err = new Error('Album not found');
    err.status = 404;
    throw err;
  }
  next();
});

module.exports = Album;
