'use strict';

var express = require('express'),
    path = require('path'),
    app = express();

// view engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'pug');


// add req to all views
app.use(function(req, res, next) {
  res.locals.req = req;
  next();
});

app.use(require('serve-favicon')(path.join(__dirname, 'public', 'favicon.ico')));
app.use(require('morgan')('dev'));
app.use('/js', require('browserify-middleware')([
  {'./public/javascripts/album.js': {run: true}},
  '@fancyapps/fancybox',
  'jquery'
]));
app.use(express.static(path.join(__dirname, 'public')));
app.use('/', require('./router'));

// catch 404 and forward to error handler
app.use(function(req, res, next) {
  var err = new Error('Not Found');
  err.status = 404;
  next(err);
});

// error handler
app.use(function(err, req, res, next) {
  // set locals, only providing error in development
  res.locals.message = err.message;
  res.locals.error = req.app.get('env') === 'development' ? err : {};

  // render the error page
  res.status(err.status || 500);
  res.render('error');
});

module.exports = app;
