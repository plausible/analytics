const scriptVariant = document.currentScript.getAttribute('variant')

// how to import the server address from '../support/server.js' ?
const localServerAddr = 'http://localhost:3000'

let script = document.createElement('script')
script.src = `${localServerAddr}/tracker/js/${scriptVariant}`

document.getElementsByTagName('head')[0].appendChild(script)