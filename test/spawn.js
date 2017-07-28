'use strict';

var Promise = require("bluebird");

module.exports = function(command, args, options) {
  return new Promise(function(resolve, reject) {
    var process = require('child_process').spawn(command, args, options);

    // process.stdout.on('data', function(data) {
    //   console.log(data.toString());
    // });

    process.stderr.on('data', function(err) {
      reject(err.toString());
    });

    process.on('exit', function() {
      resolve();
    });
  });
};
