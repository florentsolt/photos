function tw(url) {
  url = 'http://twitter.com/intent/tweet?text=&url=' + encodeURI(url);
  window.open(url, "twshare", "height=400,width=550,resizable=1,toolbar=0,menubar=0,status=0,location=0");
}
function fb(url) {
  url = 'http://www.facebook.com/sharer.php?u=' + encodeURI(url);
  window.open(url, "fbshare", "height=380,width=660,resizable=0,toolbar=0,menubar=0,status=0,location=0,scrollbars=0"); 
}

function pin(url, image) {
  url = 'http://pinterest.com/pin/create/button/?url=' + encodeURI(url) + '&media=' + encodeURI(image);
  window.open(url, "pinshare", "height=270,width=630,resizable=0,toolbar=0,menubar=0,status=0,location=0,scrollbars=0");
}

