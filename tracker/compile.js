const uglify = require("uglify-js");
const fs = require('fs')
const path = require('path')
const Handlebars = require("handlebars");
const g = require("generatorics");
const { parseArgs } = require('node:util');
const { canSkipCompile } = require("./compiler/can-skip-compile");
const { tracker_script_version } = require("./package.json");

const { values } = parseArgs({
  options: {
    'target': {
      type: 'string',
    },
    'help': {
      type: 'boolean',
    }
  }
})

if (values.help) {
  console.log('Usage: node compile.js [options]');
  console.log('Options:');
  console.log('  --target hash,outbound-links,exclusions   Only compile variants that contain all specified features');
  console.log('  --help                                    Show this help message');
  process.exit(0);
}

const targetVariants = values.target ? values.target.split(',') : null;

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
let variants = [...g.clone.powerSet(base_variants)].map(a => a.sort());

if (targetVariants) {
  variants = variants.filter(variant =>
    targetVariants.every(target => variant.includes(target))
  )
}

const startTime = Date.now();
console.log(`Starting compilation of ${variants.length} variants...`);

variants.map(variant => {
  const options = variant.map(variant => variant.replace('-', '_')).reduce((acc, curr) => (acc[curr] = true, acc), {})
  const ext = variant.length > 0 ? `.${variant.join('.')}` : ''

  compilefile(relPath('src/plausible.js'), relPath(`../priv/tracker/js/plausible${ext}.js`), options)
})

console.log(`Completed compilation of ${variants.length} variants in ${((Date.now() - startTime) / 1000).toFixed(2)}s`);
