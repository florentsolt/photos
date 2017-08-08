'use strict';

module.exports = [];

// catch 404 and forward to error handler
module.exports[404] = (req, res, next) => {
  var err = new Error('Not found');
  err.status = 404;
  next(err);
};

// error handler
module.exports[500] = (err, req, res, next) => {
  res.writeHead(err.status || 500, {'Content-Type': 'text/html'});
  req.log.push(err.stack);
  res.end(res.render('error', {
    message: err.message
  }));
};
