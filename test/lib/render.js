'use strict';

var Promise = require("bluebird"),
    fs = require('fs'),
    path = require('path'),
    mustache = require('mustache'),
    cache = {};

Promise.promisifyAll(fs);

module.exports = (req, res, next) => {
  res.render = (viewName, locals) => {
    locals = (typeof locals !== 'object' ? {} : locals);
    locals.req = req;
    Promise
      .all(['layout', viewName])
      .map(filename => {
        if (!cache[filename]) {
          return fs.readFileAsync(path.join(__dirname, '..', 'views', filename + '.mustache'))
            .then(buffer => (cache[filename] = buffer.toString()));
        } else {
          return cache[filename];
        }
      })
      .then(templates => {
        locals.content = mustache.render(templates[1].toString(), locals);
        res.end(mustache.render(templates[0].toString(), locals));
      });
  };
  next();
};
