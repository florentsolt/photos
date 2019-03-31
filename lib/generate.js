'use strict';

var config = require('../config'),
    util = require('util'),
    path = require('path'),
    _fs = require('fs'),
    fs = {
      exists: util.promisify(_fs.exists),
      mkdir: util.promisify(_fs.mkdir),
      mkdirp: util.promisify(require('fs.extra').mkdirp),
      which: util.promisify(require('which')),
      readFile: util.promisify(_fs.readFile),
      writeFile: util.promisify(_fs.writeFile),
      readdir: util.promisify(_fs.readdir),
      symlink: util.promisify(_fs.symlink),
      unlink: util.promisify(_fs.unlink)
    },
    exec = util.promisify(require('child_process').execFile),
    hasha = require('hasha'),
    leftPad = require('left-pad'),
    exif = require('fast-exif'),
    sizeOf = util.promisify(require('image-size'));

async function checkBinaries() {
  let binaries = ['vipsthumbnail', 'jpegtran', 'zip', 'montage'];

  for (let i = 0; i < binaries.length; i++) {
    try {
      await fs.which(binaries[i]);
    } catch (e) {
      throw new Error("The mandorty binary \"" + binaries[i] + "\" is not present or not in the $PATH.\n");
    }
  }
}

/*
 * Structure of an album
 * {
 *    title: '',
 *    description: '',
 *    font: '',
 *    reverse: false,
 *    dates: {
 *      from: null,
 *      to: null
 *    },
 *    pictures: []
 * }
 *
 * Structure of a picture
 * {
 *    id: 0,
 *    idStr: "00000",
 *    hash: "",
 *    filename: "",
 *    preview: {width: 0, height: 0},
 *    thumb: {width: 0, height: 0},
 *    flex: {width: 0, padding: 0}
 *    ts: 0
 *  }
 */

async function createAlbum(name, options) {
  let album;
  let folders = {
    name: null,
    albums: path.join(__dirname, '..', 'albums'),
    album: null,
    uploads: path.join(__dirname, '..', 'uploads'),
    upload: null
  };

  folders.album = path.join(folders.albums, name);
  folders.upload = path.join(folders.uploads, name);

  if (!await fs.exists(folders.upload)) {
    throw new Error("The upload folder " + folders.upload + " does not exists");
  }
  if (!await fs.exists(folders.albums)) {
    await fs.mkdir(folders.albums);
  }
  if (!await fs.exists(folders.album)) {
    await fs.mkdir(folders.album);
  }

  for (let folder of ['originals', 'previews', 'thumbs']) {
    folders[folder] = path.join(folders.album, folder);
    if (!await fs.exists(folders[folder])) {
      await fs.mkdirp(folders[folder]);
    }
  }

  let albumFilename = path.join(folders.album, 'album.json');
  if (await fs.exists(albumFilename)) {
    album = JSON.parse(await fs.readFile(albumFilename));
  } else {
    album = {
      reverse: false,
      dates: {},
      pictures: []
    };
  }

  if (options.reverse) album.reverse = true;
  if (options.title) album.title = options.title;
  if (options.desc) album.description = options.desc;
  if (options.font) album.font = options.font;

  /*
   * Read directory in ./uploads and get checksums of .jpg
   */
  let checksums = [];
  for (let file of (await fs.readdir(folders.upload))) {
    if (path.extname(file) === '.jpg') {
      try {
        let hash = await hasha.fromFile(path.join(folders.upload, file), {algorithm: 'md5'});
        checksums.push([file, hash]);
      } catch (e) {
        checksums.push([file, false]);
      }
    }
  }

  let i = 0;
  for (let checksum of checksums) {
    i++;
    let file = checksum[0];
    let hash = checksum[1];

    if (album.pictures[i - 1] && hash !== false && album.pictures[i - 1].hash === hash) {
      /*
       * Skip existing files with same checksum
       */
    } else {
      /*
       * Create symlink in ./originals
       */
      let idStr = leftPad(i, 5, 0);
      let target = name.replace(/[ _+()]/g, '-').replace(/-+/, '-') + '-' + idStr + '.jpg';
      if (await fs.exists(path.join(folders.originals, target))) {
        await fs.unlink(path.join(folders.originals, target));
      }
      console.log('symlink', file, 'to', target);
      await fs.symlink(path.join(folders.upload, file), path.join(folders.originals, target));
      album.pictures[i - 1] = {filename: target, id: i, idStr: idStr, hash: hash};

      /*
       * Extract date from EXIF metadata
       */
      let data = await exif.read(path.join(folders.originals, target));
      let date;
      if (data && data.exif) {
        date = data.exif.DateTimeOriginal || data.exif.DateTimeDigitized || data.image.ModifyDate;
        date = date.toISOString().slice(0, 10);
      }
      if (!album.dates.from || album.dates.from > date) {
        album.dates.from = date;
      }
      if (!album.dates.to || album.dates.to < date) {
        album.dates.to = date;
      }

      /*
       * Resize original and save them into ./previews/ and ./thumbs/
       */
      let original = await sizeOf(path.join(folders.originals, target));
      delete(original.type);
      album.pictures[i - 1].original = original;
      for (let type of ["previews", "thumbs"]) {
        let key = type.substr(0, type.length - 1);
        let output = path.join(folders[type], target);
        console.log("generate", key, "for", target);

        await exec('vipsthumbnail', [
                   '-s', config[key],
                   path.join(folders.originals, target),
                   '-o', output + '[Q=' + config.quality + ']'
        ]);
        await exec('jpegtran', ['-optimize', '-copy', 'none', '-progressive', '-outfile', output, output]);
        let dimensions = await sizeOf(output);
        delete(dimensions.type);
        album.pictures[i - 1][key] = dimensions;
      }

      /*
       * Compute flex values for the layout
       */
      album.pictures[i - 1].flex = {
        width: Math.floor(album.pictures[i - 1].thumb.width * 200 / album.pictures[i - 1].thumb.height),
        padding: album.pictures[i - 1].thumb.height / album.pictures[i - 1].thumb.width * 100
      };

    }
  }

  /*
   * Save album informations in a JSON file
   */
  console.log('save album meta data');
  await fs.writeFile(path.join(folders.album, 'album.json'), JSON.stringify(album, null, 4));

  /*
   * Generate the album zip file
   */
  console.log("generate the zip file");
  try {
    await exec('zip',
      ['-u', '-X', '-D', '-0', path.join(folders.album, 'album.zip')].concat(album.pictures.map(picture => picture.filename)),
      {cwd: folders.originals});
  } catch (e) {
    // error code 12 stands for "zip has nothing to do" cf. man
    if (typeof e.cmd !== 'string' || !e.cmd.startsWith('zip') || e.code !== 12) throw e;
  }

  /*
   * Select sample images
   */
  let count = 8;
  let samples = [];
  let files = album.pictures.map(picture => picture.filename);
  if (count > album.pictures.length) {
    for (let i = 0; i < count; i++) {
      samples.push(files[i % files.length]);
    }
  } else {
    for (let i = 0; i < count; i++) {
      let index = Math.floor(Math.random() * files.length);
      samples.push(files.splice(index, 1)[0]);
    }
  }

  /*
   * Generate the sample images
   */
  for (let index = 0; index < samples.length; index++) {
    let sample = samples[index];
    console.log("generate sample image number", index);
    let output = path.join(folders.album, 'sample-' + index + '.jpg');
    await exec('vipsthumbnail', ['-s', '200x200', '-m', 'attention', path.join(folders.previews, sample), '-o', output + '[Q=' + config.quality + ']']);
    samples[index] = output;
  }

  /*
   * Generate the sample collage
   */
  console.log("generate samples collage");
  await exec('montage', ['-background', '#D7D7D7FF', '-tile', '4x2', '-geometry', '200x200+0+0', '-borderwidth', '1', '-bordercolor', '#D7D7D7FF'].concat(samples).concat([path.join(folders.album, 'samples.jpg')]));

  /*
   * Cleanup
   */
  for (let sample of samples) {
    await fs.unlink(sample);
  }
}

module.exports = {
  checkBinaries: checkBinaries,
  createAlbum: createAlbum
};
