'use strict';

var util = require('util'),
    _fs = require('fs'),
    fs = {
      readFile: util.promisify(_fs.readFile)
    },
    wrap = require('./wrap'),
    uglify = require("uglify-js"),
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
    cache = false,
    date;

async function buildCache() {
  if (!cache) {
    let scripts = {};
    let sourceMap = {
      includeSources: true,
      url: 'inline'
    };
    for (let filename of filenames) {
      scripts[filename] = (await fs.readFile(filename)).toString();
    }
    date = (new Date()).toUTCString();
    cache = uglify.minify(scripts, {
      sourceMap: process.env.NODE_ENV === 'production' ? {} : sourceMap,
      ie8: false
    }).code;
  }
}

module.exports = wrap(async function(req, res, next) {
  await buildCache();
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
});

// Build cache on startup
buildCache();