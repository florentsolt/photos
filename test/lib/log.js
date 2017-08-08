'use strict';

module.exports = function(req, res, next) {
  var url = req.url;
  var method = req.method;
  var timestamp = process.hrtime();
  req.log = [];
  res.on('finish', () => {
    var now = process.hrtime();
    var ms = (now[0] - timestamp[0]) * 1e3 + (now[1] - timestamp[1]) * 1e-6;
    var msg = res.statusCode + " -> " + method + " " + url + " " + ms.toFixed(2) + " ms\n";
    process.stdout.write(msg + req.log.join("\n")  + (req.log.length > 0 ? "\n" : ""));
  });
  next();
};
