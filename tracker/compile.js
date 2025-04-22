const uglify = require("uglify-js");
const fs = require('fs')
const path = require('path')
const Handlebars = require("handlebars");
const g = require("generatorics");
const { canSkipCompile } = require("./dev-compile/can-skip-compile");
const { tracker_script_version } = require("./package.json");

if (process.env.NODE_ENV === 'dev' && canSkipCompile()) {
  console.info('COMPILATION SKIPPED: No changes detected in tracker dependencies')
  process.exit(0)
}

Handlebars.registerHelper('any', function (...args) {
  return args.slice(0, -1).some(Boolean)
})

Handlebars.registerPartial('customEvents', Handlebars.compile(fs.readFileSync(relPath('src/customEvents.js')).toString()))

function relPath(segment) {
  return path.join(__dirname, segment)
}

function compilefile(input, output, templateVars = {}) {
  const code = fs.readFileSync(input).toString()
  const template = Handlebars.compile(code)
  const rendered = template({ ...templateVars, TRACKER_SCRIPT_VERSION: tracker_script_version })
  const result = uglify.minify(rendered)
  if (result.code) {
    fs.writeFileSync(output, result.code)
  } else {
    throw new Error(`Failed to compile ${output.split('/').pop()}.\n${result.error}\n`)
  }
}

const base_variants = ["hash", "outbound-links", "exclusions", "compat", "local", "manual", "file-downloads", "pageview-props", "tagged-events", "revenue"]
const variants = [...g.clone.powerSet(base_variants)].filter(a => a.length > 0).map(a => a.sort());

compilefile(relPath('src/plausible.js'), relPath('../priv/tracker/js/plausible.js'))
compilefile(relPath('src/p.js'), relPath('../priv/tracker/js/p.js'))

variants.map(variant => {
  const options = variant.map(variant => variant.replace('-', '_')).reduce((acc, curr) => (acc[curr] = true, acc), {})
  compilefile(relPath('src/plausible.js'), relPath(`../priv/tracker/js/plausible.${variant.join('.')}.js`), options)
})
