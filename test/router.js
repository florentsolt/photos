'use strict';

var express = require('express'),
    Promise = require("bluebird"),
    less = require('less'),
    path = require('path'),
    fs = require('fs'),
    rp = require('request-promise'),
    Album = require('./album'),
    cache = {};

Promise.promisifyAll(fs);
var router = express.Router();

// Main index
router.get('/', function(req, res, next) {
    Album.all()
      .then(albums => res.render('index', {
        title: 'Albums Index',
        albums: albums
      }));
});

// Add album object to all requests
router.get('/:album*', function(req, res, next) {
  Album.find(req.params.album).then(album => album.load()).then(album => {
    req.album = album;
    next();
  }).catch(() => {
    res.end();
    res.status(404).end();
  });
});

// Add css object to index
router.get('/:album', function(req, res, next) {
  if (cache[req.album.name]) {
    res.css = cache[req.album.name];
    next();
  } else {
    var promises = [];
    promises.push(rp('http://fonts.googleapis.com/css?family=' + req.album.font));
    promises.push(fs.readFileAsync(path.join(__dirname, 'public', 'stylesheets', 'style.less')));
    Promise.all(promises).map(css => less.render(css.toString(), {
      compress: true,
      globalVars: {font: req.album.font}
    })).then(css => {
      res.css = cache[req.album.name] = css[0].css + css[1].css;
      next();
    })
  }
});

// Album index
router.get('/:album', function(req, res, next) {
  res.render('album', {
    album: req.album,
    css: res.css
  });
});

// Thumbs images
router.get('/:album/:type/:filename', function(req, res, next) {
  var options = {
    root: path.join(__dirname, 'albums', req.params.album, req.params.type),
    dotfiles: 'deny',
    headers: {
      'x-timestamp': Date.now(),
      'x-sent': true
    }
  };
  res.sendFile(req.params.filename, options, err => {
    if (err) next(err);
  });
});


// /:album/samples.jpg
router.get('/:album/samples.jpg', function(req, res, next) {
  var options = {
    root: path.join(__dirname, 'albums', req.params.album),
    dotfiles: 'deny',
    headers: {
      'x-timestamp': Date.now(),
      'x-sent': true
    }
  };
  res.sendFile('samples.jpg', options, err => {
    if (err) next(err);
  });
});

// /:album/zip

module.exports = router;
