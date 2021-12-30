const uglify = require("uglify-js");
const fs = require('fs')
const path = require('path')
const Handlebars = require("handlebars");
const g = require("generatorics");

function relPath(segment) {
  return path.join(__dirname, segment)
}

function compilefile(input, output, templateVars = {}) {
  const code = fs.readFileSync(input).toString()
  const template = Handlebars.compile(code)
  const rendered = template(templateVars)
  const result = uglify.minify(rendered)
  fs.writeFileSync(output, result.code)
}

const base_variants = ["hash", "outbound-links", "exclusions", "compat", "local", "manual"]
const variants = [...g.clone.powerSet(base_variants)].filter(a => a.length > 0).map(a => a.sort());

compilefile(relPath('src/plausible.js'), relPath('../priv/tracker/js/plausible.js'))
compilefile(relPath('src/plausible.js'), relPath('../priv/tracker/js/analytics.js'))
compilefile(relPath('src/p.js'), relPath('../priv/tracker/js/p.js'))

variants.map(variant => {
  const options = variant.map(variant => variant.replace('-', '_')).reduce((acc, curr) => (acc[curr] = true, acc), {})
  compilefile(relPath('src/plausible.js'), relPath(`../priv/tracker/js/plausible.${variant.join('.')}.js`), options)
})
