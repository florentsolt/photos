'use strict';

var path = require('path'),
    fs = require('fs'),
    Promise = require("bluebird"),
    Mustache = require('mustache'),
    cache = {};

Promise.promisifyAll(fs);

module.exports = function(req, res, next) {
  res.render = (viewName, locals) => {
    locals = (typeof locals !== 'object' ? {} : locals);
    locals.req = req;
    locals.res = res;
    var filenames = [
      path.join(__dirname, '..', 'views', viewName + '.mustache'),
      path.join(__dirname, '..', 'views', 'layout.mustache')
    ];

    Promise
      .map(filenames, filename => {
        if (process.env.NODE_ENV === 'production' && cache[filename]) {
          return cache[filename];
        }
        return fs.readFileAsync(filename).then(view => (cache[filename] = view));
      })
      .then(views => {
        locals.content = Mustache.render(views[0].toString(), locals);
        res.end(Mustache.render(views[1].toString(), locals));
      });
  };
  next();
};
