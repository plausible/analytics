import iframeResize from 'iframe-resizer/js/iframeResizer'

var iframes = iframeResize({
  heightCalculationMethod: 'taggedElement',
  onInit: onInit,
  checkOrigin: false
}, '[plausible-embed]')

function onInit() {
  var iframe = iframes[0]
  var styles = iframe.getAttribute('styles')

  if (styles) {
    iframe.iFrameResizer.sendMessage({
      type: 'load-custom-styles',
      opts: {
        styles: styles
      }
    })
  }
}
