'use strict';

var path = require('path'),
    util = require('util'),
    _fs = require('fs'),
    fs = {
      readFile: util.promisify(_fs.readFile)
    },
    Mustache = require('mustache'),
    cache = {};

module.exports = function(req, res, next) {
  res.render = async function (viewName, locals) {
    let view = path.join(__dirname, '..', 'views', viewName + '.mustache');
    let layout = path.join(__dirname, '..', 'views', 'layout.mustache');
    locals = (typeof locals !== 'object' ? {} : locals);
    locals.req = req;
    locals.res = res;

    if (process.env.NODE_ENV !== 'production' || !cache[view]) {
      cache[view] = (await fs.readFile(view)).toString();
    }

    if (process.env.NODE_ENV !== 'production' || !cache[layout]) {
      cache[layout] = (await fs.readFile(layout)).toString();
    }

    locals.content = Mustache.render(cache[view], locals);
    res.end(Mustache.render(cache[layout], locals));
  };
  next();
};
