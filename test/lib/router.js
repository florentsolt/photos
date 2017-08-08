'use strict';

var Album = require('./album'),
    Router = require('connect-route');

module.export = {};

module.exports.find = Router(router => {
  router.get('/:album', (req, res, next) => {
    Album.find(req.params.album).then(album => album.load()).then(album => {
      req.album = album;
      next();
    }).catch(() => {
      var err = new Error('Album not found');
      err.status = 404;
      next(err);
    });
  });
});

module.exports.routes = Router(router => {
  // Albums index
  router.get('/', (req, res, next) => {
    Album.all()
      .then(albums => res.render('index', {
        title: 'Albums Index',
        albums: albums
      }));
  });

  // Album index
  router.get('/:ablum', (req, res, next) => {
    // FIXME use isFresh
    res.render('album', {
      album: req.album,
      css: res.css
    });
  });
});
