import iframeResize from 'iframe-resizer/js/iframeResizer'

const iframe = document.querySelector('[plausible-embed]')
const options = {
  heightCalculationMethod: 'taggedElement'
}
if (iframe.getAttribute('background')) {
  options.bodyBackground = iframe.getAttribute('background')
}

iframeResize(options, '[plausible-embed]')
