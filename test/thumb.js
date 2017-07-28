#!/usr/bin/env node
'use strict';

var Promise = require("bluebird"),
    program = require('commander'),
    colors = require('colors'),
    path = require('path'),
    fs = require('fs'),
    winston = require('winston'),
    util = require('util'),
    execFile = util.promisify(require('child_process').execFile);

Promise.promisifyAll(fs);

program
  .version('0.4.2')
  .option('-a, --album [name]', 'specify an album')
  .option('-p, --path [directory]', 'specify the directory where albums are')
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

var directory = program.path ?
  path.join(program.path, program.album) :
  path.join(__dirname, '..', 'albums', program.album);

fs.readdirAsync(directory)
  .each(function(filename) {
    var promises = [],
        output;

    if (filename.toLowerCase().match(/\.jpg$/)) {
      winston.debug(filename);
      output = path.join(__dirname, 'cache', 'preview-' + filename);

      promises.push(execFile('vipsthumbnail', [
        '-s', '2560x1600',
        path.join(directory, filename),
        '-o', output + '[Q=85]'
      ]).then(function() {
        return execFile('jpegtran', [
          '-optimize',
          '-copy', 'none',
          '-progressive',
          '-outfile', output,
          output
        ]);
      }));

      output = path.join(__dirname, 'cache', 'thumb-' + filename);

      promises.push(execFile('vipsthumbnail', [
        '-s', 'x300',
        path.join(directory, filename),
        '-o', output + '[Q=85]'
      ]).then(function() {
        return execFile('jpegtran', [
          '-optimize',
          '-copy', 'none',
          '-progressive',
          '-outfile', output,
          output
        ]);
      }));

    }

    return Promise.all(promises);
  });
