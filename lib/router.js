'use strict';

var cookie = require('cookie'),
    sha1 = require('js-sha1'),
    salt = sha1("photo" + new Date() + Math.random()),
    config = require('../config'),
    Album = require('./album');

module.exports = (req, res, next) => {
  // FIXME use isFresh
  if (req.album) {
    res.render('album', {
      album: req.album
    });
  } else {
    var cookies = cookie.parse(req.headers.cookie || "");
    if (config.password === false || cookies.pwd && cookies.pwd === sha1(salt + config.password)) {
      Album.all()
        .then(albums => res.render('index', {
          albums: albums
        }));
    } else {
      req.log.push('bad or missing password');
      res.render('password', {
        salt: salt
      });
    }
  }
};
