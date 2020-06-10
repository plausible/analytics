const uglify = require("uglify-js");
const fs = require('fs')
const path = require('path')

function relPath(segment) {
  return path.join(__dirname, segment)
}

function compilefile(input, output) {
  const code = fs.readFileSync(input).toString()
  const result = uglify.minify(code)
  fs.writeFileSync(output, result.code)
}

compilefile(relPath('src/plausible.js'), relPath('../priv/tracker/js/plausible.js'))
compilefile(relPath('src/p.js'), relPath('../priv/tracker/js/p.js'))
fs.copyFileSync(relPath('../priv/tracker/js/plausible.js'), relPath('../priv/tracker/js/analytics.js'))
