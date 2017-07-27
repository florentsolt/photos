$.fancybox.defaults.loop = false;

$.fancybox.defaults.btnTpl.download = '<a class="fancybox-download fancybox-button"><div class="download icon"></div></a>';

$.fancybox.defaults.buttons = [
  'download',
  'fullScreen',
  'close'
];

$.fancybox.defaults.beforeShow = function( instance, current ) {
  $('.fancybox-download').attr('href', current.opts.$orig.attr('data-download-url'));
}
