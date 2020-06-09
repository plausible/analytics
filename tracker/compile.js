const uglify = require("uglify-js");
const fs = require('fs')
const path = require('path')

const scheme = process.env.SCHEME || "https"
const host = process.env.HOST || "plausible.io"
const baseUrl = scheme + "://" + host

function relPath(segment) {
  return path.join(__dirname, segment)
}

function compilefile(input, output) {
  const code = fs.readFileSync(input)
    .toString()
    .replace('BASE_URL', "'" + baseUrl + "'")
  const result = uglify.minify(code)
  fs.writeFileSync(output, result.code)
}

compilefile(relPath('src/plausible.js'), relPath('../priv/static/js/plausible.js'))
compilefile(relPath('src/p.js'), relPath('../priv/static/js/p.js'))
fs.copyFileSync(relPath('../priv/static/js/plausible.js'), relPath('../priv/static/js/analytics.js'))
