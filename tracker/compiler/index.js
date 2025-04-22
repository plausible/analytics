import uglify from 'uglify-js'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import Handlebars from 'handlebars'
import variants from './variants.json' with { type: 'json' }
import { canSkipCompile } from './can-skip-compile.js'
import packageJson from '../package.json' with { type: 'json' }

const __dirname = path.dirname(fileURLToPath(import.meta.url))

Handlebars.registerHelper('any', function (...args) {
  return args.slice(0, -1).some(Boolean)
})

Handlebars.registerPartial('customEvents', Handlebars.compile(fs.readFileSync(relPath('../src/customEvents.js')).toString()))

export function compileAll(options = {}) {
  if (process.env.NODE_ENV === 'dev' && canSkipCompile()) {
    console.info('COMPILATION SKIPPED: No changes detected in tracker dependencies')
    return
  }

  let targetVariants = variants.variants
  if (options.targets) {
    targetVariants = targetVariants.filter(variant =>
      options.targets.every(target => variant.features.includes(target))
    )
  }

  const startTime = Date.now();
  console.log(`Starting compilation of ${targetVariants.length} variants...`)

  targetVariants.forEach(compile)

  console.log(`Completed compilation of ${targetVariants.length} variants in ${((Date.now() - startTime) / 1000).toFixed(2)}s`);
}

function compile({ name, features }) {
  const options = features.map(variant => variant.replace('-', '_')).reduce((acc, curr) => (acc[curr] = true, acc), {})

  compilefile(relPath('../src/plausible.js'), relPath(`../../priv/tracker/js/${name}`), options)
}

function relPath(segment) {
  return path.join(__dirname, segment)
}

function compilefile(input, output, templateVars = {}) {
  const code = fs.readFileSync(input).toString()
  const template = Handlebars.compile(code)
  const rendered = template({ ...templateVars, TRACKER_SCRIPT_VERSION: packageJson.tracker_script_version })
  const result = uglify.minify(rendered)
  if (result.code) {
    fs.writeFileSync(output, result.code)
  } else {
    throw new Error(`Failed to compile ${output.split('/').pop()}.\n${result.error}\n`)
  }
}
