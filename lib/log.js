'use strict';

var chalk = require('chalk');

module.exports = (req, res, next) => {
  var url = req.url;
  var method = req.method;
  var timestamp = process.hrtime();
  req.log = [];
  res.on('finish', () => {
    var now = process.hrtime();
    var ms = (now[0] - timestamp[0]) * 1e3 + (now[1] - timestamp[1]) * 1e-6;
    var statusCode = res.statusCode < 400 ? chalk.green(res.statusCode) : chalk.red(res.statusCode);
    var msg =  statusCode + " " + chalk.yellow(method) + " " + url + " " + chalk.cyan(ms.toFixed(2) + " ms\n");

    if (process.env.NODE_ENV !== 'production') {
      process.stdout.write(chalk.grey(req.log.join("\n")  + (req.log.length > 0 ? "\n" : "")));
    }
    process.stdout.write(msg);
    delete(req.log);
  });
  next();
};
