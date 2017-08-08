'use strict';

var Promise = require("bluebird"),
    fs = require('fs'),
    http = require('http'),
    path = require('path'),
    less = require("less"),
    filenames = {
      common: path.join(__dirname, '..', 'views', 'common.less'),
      album: path.join(__dirname, '..', 'views', 'album.less')
    },
    cache = {};

Promise.promisifyAll(fs);

// Default style
fs.readFileAsync(filenames.common)
  .catch(() => "")
  .then(css => less.render(css.toString(), {compress: true}))
  .then(css => (cache[""] = css.css));

module.exports = (req, res, next) => {
  if (req.album) {
    if (cache[req.album.name]) {
      res.css = cache[""] + cache[req.album.name];
      next();
    } else {
      var promises = [];

      promises.push(
        new Promise((resolve, reject) => {
          http.get('http://fonts.googleapis.com/css?family=' + req.album.font, (res) => {
            if (res.statusCode !== 200) {
              res.resume(); // consume response data to free up memory
              return reject("");
            } else {
              res.setEncoding('utf8');
              let css = '';
              res.on('data', chunk => (css += chunk));
              res.on('end', () => resolve(css));
            }
          }).on('error', () => reject(''));
        }).then(css => less.render(css.toString(), {compress: true}))
      );

      promises.push(
        fs.readFileAsync(filenames.album)
          .catch(() => "")
          .then(css => less.render(css.toString(), {compress: true, globalVars: {font: req.album.font}}))
      );
      Promise.all(promises).then(results => {
        cache[req.album.name] = results[0].css + results[1].css;
        res.css = cache[""] + cache[req.album.name];
        next();
      });
    }
  } else {
    // index
    res.css = cache[""];
    next();
  }
};
