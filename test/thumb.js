#!/usr/bin/env node
'use strict';

var Promise = require("bluebird"),
    program = require('commander'),
    colors = require('colors'),
    path = require('path'),
    fs = require('fs'),
    winston = require('winston'),
    sharp = require('sharp');

Promise.promisifyAll(fs);

program
  .version('0.4.2')
  .option('-a, --album [name]', 'specify an album')
  .option('-c, --concurrency [limit]', 'specify a concurrency limit', parseInt, 3)
  .option('-d, --debug', 'output debug information')
  .parse(process.argv);

if (!program.album) {
    program.help(function(txt) {
      return colors.red("You must specify an album name.") + "\n" + txt;
    });
}

if (program.debug) {
  winston.level = 'debug';
}

var directory = path.join(__dirname, '..', 'albums', program.album);
fs.readdirAsync(directory)
  .map(function(filename) {
    var promises = [],
        output;

    if (filename.toLowerCase().match(/\.jpg$/)) {
      winston.debug(filename);
      output = path.join(__dirname, 'cache', 'preview-' + filename);
      promises.push(sharp(path.join(directory, filename))
        .resize(2560, 1600)
        .jpeg({quality: 85, progressive: true, optimiseScans: true})
        .toFile(output)
      );

      output = path.join(__dirname, 'cache', 'thumb-' + filename);
      promises.push(sharp(path.join(directory, filename))
        .resize(null, 300)
        .jpeg({quality: 85, progressive: true})
        .toFile(output)
      );
    }

    return Promise.all(promises);
  }, {concurrency: program.concurrency});
