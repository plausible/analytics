const uglify = require("uglify-js");
const fs = require('fs')
const path = require('path')
const Handlebars = require("handlebars");

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

compilefile(relPath('src/plausible.js'), relPath('../priv/tracker/js/plausible.js'))
compilefile(relPath('src/plausible.js'), relPath('../priv/tracker/js/plausible.exclusions.js'), {exclusionMode: true})
compilefile(relPath('src/plausible.js'), relPath('../priv/tracker/js/plausible.hash.js'), {hashMode: true})
compilefile(relPath('src/plausible.js'), relPath('../priv/tracker/js/plausible.hash.exclusions.js'), {hashMode: true, exclusionMode: true})
compilefile(relPath('src/plausible.js'), relPath('../priv/tracker/js/plausible.outbound-links.js'), {outboundLinks: true})
compilefile(relPath('src/plausible.js'), relPath('../priv/tracker/js/plausible.exclusions.outbound-links.js'), {outboundLinks: true, exclusionMode: true})
compilefile(relPath('src/plausible.js'), relPath('../priv/tracker/js/plausible.hash.outbound-links.js'), {hashMode: true, outboundLinks: true})
compilefile(relPath('src/plausible.js'), relPath('../priv/tracker/js/plausible.hash.exclusions.outbound-links.js'), {hashMode: true, outboundLinks: true, exclusionMode: true})
compilefile(relPath('src/p.js'), relPath('../priv/tracker/js/p.js'))
fs.copyFileSync(relPath('../priv/tracker/js/plausible.js'), relPath('../priv/tracker/js/analytics.js'))
