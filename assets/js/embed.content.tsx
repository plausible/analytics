import 'iframe-resizer/js/iframeResizer.contentWindow'

window.iFrameResizer = {
  onMessage: function(msg) {
    if (msg.type === 'load-custom-styles') {
      addCustomStyles(msg.opts)
    }
  }
}

function addCustomStyles(opts) {
  var style = document.createElement('style');
  style.innerHTML = opts.styles

  document.head.appendChild(style);
}
