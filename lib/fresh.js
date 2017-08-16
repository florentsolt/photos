'use strict';

var fresh = require('fresh');

module.exports = (req, res) => {
  return fresh(req.headers, {
    'etag': res.getHeader('ETag'),
    'last-modified': res.getHeader('Last-Modified')
  });
};
