'use strict';

var Promise = require("bluebird"),
    fs = require('fs'),
    http = require('http'),
    path = require('path'),
    less = require("less"),
    _cache = {};

Promise.promisifyAll(fs);

function cache(req, style, vars) {
  if (process.env.NODE_ENV === 'production' && _cache[style]) {
    return Promise.resolve(_cache[style]);
  }

  req.log.push('loading css ' + style);

  // it's an url
  if (style.startsWith('http')) {
    return new Promise((resolve, reject) => {
      http.get(style, (res) => {
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
    })
    .then(css => less.render(css, {compress: true}))
    .then(css => {
      if (process.env.NODE_ENV === 'production') _cache[style] = css.css;
      return css.css;
    });

  } else {
    // it's a local file
    var filename = path.join(__dirname, '..', 'views', style + '.less');
    return fs.readFileAsync(filename)
      .catch(() => "")
      .then(css => less.render(css.toString(), {compress: true, globalVars: vars || {}}))
      .then(css => {
        if (process.env.NODE_ENV === 'production') _cache[style] = css.css;
        return css.css;
      });
  }
}

module.exports = (req, res, next) => {
  if (req.album) {
    var promises = [
      cache(req, 'http://fonts.googleapis.com/css?family=' + req.album.font),
      cache(req, 'album', {font: req.album.font}),
      cache(req, 'common')
    ];

    Promise.all(promises)
      .then(results => {
        res.css = results[0] + results[1] + results[2];
        next();
      });
  } else {
    // index
    cache(req, 'common').then(css => {
      res.css = css;
      next();
    });
  }
};
