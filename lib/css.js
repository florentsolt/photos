'use strict';

var util = require('util'),
    _fs = require('fs'),
    fs = {
      readFile: util.promisify(_fs.readFile)
    },
    wrap = require('./wrap'),
    http = require('http'),
    path = require('path'),
    less = require("less"),
    _cache = {};

async function download(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      if (res.statusCode !== 200) {
        res.resume(); // consume response data to free up memory
        return reject("");
      } else {
        res.setEncoding('utf8');
        let buf = '';
        res.on('data', chunk => (buf += chunk));
        res.on('end', () => resolve(buf.replace(/https?:/g, '')));
      }
    }).on('error', () => reject(''));
  });
}

async function renderGoogleFont(name) {
  if (process.env.NODE_ENV !== 'production' || !_cache[name]) {
    let buf = await download('http://fonts.googleapis.com/css?family=' + name);
    let css = await less.render(buf.toString(), {compress: true});
    _cache[name] = css.css;
  }
  return _cache[name];
}

async function renderLessView(name, vars) {
  if (process.env.NODE_ENV !== 'production' || !_cache[name]) {
    let filename = path.join(__dirname, '..', 'views', name + '.less');
    let buf = await fs.readFile(filename);
    let css = await less.render(buf.toString(), {compress: true, globalVars: vars || {}});
    _cache[name] = css.css;
  }
  return _cache[name];
}

module.exports = wrap(async function(req, res, next) {
  if (req.album) {
    req.log.push('loading google font css ' + req.album.font);
    let font = renderGoogleFont(req.album.font);
    req.log.push('loading css album');
    let album = renderLessView("album", {font: req.album.font});
    req.log.push('loading css common');
    let common = renderLessView("common");
    res.css = await font + await common + await album;
  } else {
    req.log.push('loading css common');
    res.css = await renderLessView("common");
  }
  next();
});