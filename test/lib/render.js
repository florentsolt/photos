'use strict';

var path = require('path'),
    pug = require('pug');

module.exports = function(req, res, next) {
  res.render = (viewName, locals) => {
    var filename = path.join(__dirname, '..', 'views', viewName + '.pug');
    var view = pug.compileFile(filename, {cache: true});
    locals = (typeof locals !== 'object' ? {} : locals);
    locals.req = req;
    res.end(view(locals));
  };
  next();
};
