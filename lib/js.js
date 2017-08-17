'use strict';

var Promise = require("bluebird"),
    uglify = require("uglify-js"),
    fs = require('fs'),
    path = require('path'),
    etag = require('etag'),
    isFresh = require('./fresh'),
    filenames = [
      path.join(__dirname, '..', 'node_modules', 'jquery', 'dist', 'jquery.js'),
      path.join(__dirname, '..', 'node_modules', 'vanilla-lazyload', 'dist', 'lazyload.js'),
      path.join(__dirname, '..', 'node_modules', '@fancyapps', 'fancybox', 'dist', 'jquery.fancybox.js'),
      path.join(__dirname, '..', 'node_modules', 'js-sha1', 'build', 'sha1.min.js'),
      path.join(__dirname, '..', 'views', 'album.js')
    ],
    cache,
    date;

Promise.promisifyAll(fs);

Promise.all(filenames)
  .map(filename => fs.readFileAsync(filename))
  .then(files => {
    var scripts = {},
        sourceMap = {
      includeSources: true,
      url: 'inline'
    };
    files.forEach((file, index) => {
      scripts[filenames[index]] = file.toString();
    });
    cache = uglify.minify(scripts, {
      sourceMap: process.env.NODE_ENV === 'production' ? {} : sourceMap,
      ie8: false
    }).code;
    date = (new Date()).toUTCString();
  });

module.exports = (req, res, next) => {
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Content-Type', 'application/javascript');
  res.setHeader('ETag', etag(cache));
  res.setHeader('Last-Modified', date);
  if (isFresh(req, res)) {
    res.statusCode = 304;
    res.end();
  } else {
    res.end(cache);
  }
};
