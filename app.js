'use strict';

var connect = require('connect'),
    path = require('path'),
    app = connect(),
    middlewares = {
      errors: require('./lib/errors'),
      favicon: require('serve-favicon'),
      static: require('serve-static'),
      render: require('./lib/render'),
      log: require('./lib/log'),
      js: require('./lib/js'),
      css: require('./lib/css'),
      album: require('./lib/album').route,
      router: require('./lib/router')
    };

app.use(middlewares.log);
app.use(middlewares.render);

app.use(middlewares.favicon(
  path.join(__dirname, 'views', 'favicon.ico')
));
app.use('/_', middlewares.static(
  path.join(__dirname, 'albums')
));
app.use('/js', middlewares.js);
app.use('/', middlewares.album);
app.use('/', middlewares.css);
app.use('/', middlewares.router);

app.use(middlewares.errors[404]);
app.use(middlewares.errors[500]);

module.exports = app;
