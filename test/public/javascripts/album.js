var $ = window.jQuery = require('jquery');
require('@fancyapps/fancybox');

$("[data-fancybox]").fancybox({
	loop: false,
  buttons: ['download', 'fullScreen', 'close'],
  btnTpl: {
  	download: '<a class="fancybox-download fancybox-button"><div class="download icon"></div></a>'
  },
  beforeShow: function(instance, current) {
  	$('.fancybox-download').attr('href', this.opts.$orig.attr('data-download-url'));
  }
});
