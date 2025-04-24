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

  const variants = getVariantsToCompile(options)

  const startTime = Date.now();
  console.log(`Starting compilation of ${variants.length} variants...`)

  const baseCode = getCode()

  const bar = new progress.SingleBar({ clearOnComplete: true }, progress.Presets.shades_classic)
  bar.start(variants.length, 0)

  variants.forEach((variant) => {
    compileFile(variant, { ...options, baseCode })
    bar.increment()
  })

  bar.stop()

  console.log(`Completed compilation of ${variants.length} variants in ${((Date.now() - startTime) / 1000).toFixed(2)}s`);
}

export function compileFile({ name, features }, options) {
  const baseCode = options.baseCode || getCode()
  const compileVars = getCompileVars(features)

  const code = minify(baseCode, compileVars)

  if (options.returnCode) {
    return code
  } else {
    fs.writeFileSync(relPath(`../../priv/tracker/js/${name}${options.suffix}`), code)
  }
}

function getVariantsToCompile(options) {
  let targetVariants = variants.variants
  if (options.targets !== null) {
    targetVariants = targetVariants.filter(variant =>
      options.targets.every(target => variant.features.includes(target))
    )
  }
  if (options.only !== null) {
    targetVariants = targetVariants.filter(variant =>
      options.only.some(target_features => equal_lists(variant.features, target_features))
    )
  }

  return targetVariants
}

function getCode() {
  // Wrap the code in an instantly evaluating function
  return `(function(){${fs.readFileSync(relPath('../src/plausible.js')).toString()}})()`
}

function getCompileVars(features) {
  const names = features.map(feature => feature.replace('-', '_'))
  const overrides = names.reduce((acc, curr) => (acc[`COMPILE_${curr.toUpperCase()}`] = true, acc), {})

  return { ...DEFAULT_COMPILE_VARS, ...overrides }
}

function minify(baseCode, compileVars) {
  const result = uglify.minify(baseCode, {
    compress: {
      global_defs: compileVars
    }
  })

  if (result.code) {
    return result.code
  } else {
    throw result.error
  }
}

function equal_lists(a, b) {
  if (a.length != b.length) {
    return false
  }
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) {
      return false
    }
  }
  return true
}

function relPath(segment) {
  return path.join(__dirname, segment)
}
