import uglify from 'uglify-js'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import variants from './variants.json' with { type: 'json' }
import { canSkipCompile } from './can-skip-compile.js'
import packageJson from '../package.json' with { type: 'json' }
import progress from 'cli-progress'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

const DEFAULT_COMPILE_VARS = {
  COMPILE_HASH: false,
  COMPILE_OUTBOUND_LINKS: false,
  COMPILE_EXCLUSIONS: false,
  COMPILE_COMPAT: false,
  COMPILE_LOCAL: false,
  COMPILE_MANUAL: false,
  COMPILE_FILE_DOWNLOADS: false,
  COMPILE_PAGEVIEW_PROPS: false,
  COMPILE_TAGGED_EVENTS: false,
  COMPILE_REVENUE: false,
  COMPILE_TRACKER_SCRIPT_VERSION: packageJson.tracker_script_version
}

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

  const code = getCode()

  const bar = new progress.SingleBar({ clearOnComplete: true }, progress.Presets.shades_classic)
  bar.start(targetVariants.length, 0)

  targetVariants.forEach(({ name, features }) => {
    compilefile(code, relPath(`../../priv/tracker/js/${name}2`), getCompileVars(features))
    bar.increment()
  })

  bar.stop()

  console.log(`Completed compilation of ${targetVariants.length} variants in ${((Date.now() - startTime) / 1000).toFixed(2)}s`);
}

function relPath(segment) {
  return path.join(__dirname, segment)
}

function getCode() {
  return `
(function(){
  ${fs.readFileSync(relPath('../src/plausible.js')).toString()}
  ${fs.readFileSync(relPath('../src/customEvents.js')).toString()}
})();`
}

function getCompileVars(features) {
  const names = features.map(feature => feature.replace('-', '_'))
  const overrides = names.reduce((acc, curr) => (acc[`COMPILE_${curr.toUpperCase()}`] = true, acc), {})

  return { ...DEFAULT_COMPILE_VARS, ...overrides }
}

function compilefile(code, output, compileVars) {
  const result = uglify.minify(code, {
    compress: {
      global_defs: compileVars,
      passes: 2
    }
  })

  if (result.code) {
    fs.writeFileSync(output, result.code)
  } else {
    throw new Error(`Failed to compile ${output.split('/').pop()}.\n${result.error}\n`)
  }
}
