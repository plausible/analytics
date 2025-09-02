import { minifySync } from '@swc/core'
import { rollup } from 'rollup'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import variantsFile from './variants.json' with { type: 'json' }
import { canSkipCompile } from './can-skip-compile.js'
import packageJson from '../package.json' with { type: 'json' }
import progress from 'cli-progress'
import { spawn, Worker, Pool } from "threads"
import json from '@rollup/plugin-json'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

export const DEFAULT_GLOBALS = {
  COMPILE_PLAUSIBLE_WEB: false,
  COMPILE_PLAUSIBLE_NPM: false,
  COMPILE_PLAUSIBLE_LEGACY_VARIANT: false,
  COMPILE_CONFIG: false,
  COMPILE_HASH: false,
  COMPILE_OUTBOUND_LINKS: false,
  COMPILE_COMPAT: false,
  COMPILE_LOCAL: false,
  COMPILE_MANUAL: false,
  COMPILE_FILE_DOWNLOADS: false,
  COMPILE_PAGEVIEW_PROPS: false,
  COMPILE_CUSTOM_PROPERTIES: false,
  COMPILE_TAGGED_EVENTS: false,
  COMPILE_REVENUE: false,
  COMPILE_EXCLUSIONS: false,
  COMPILE_TRACKER_SCRIPT_VERSION: packageJson.tracker_script_version,
}

const ALL_VARIANTS = variantsFile.legacyVariants.concat(variantsFile.manualVariants)

export async function compileAll(options = {}) {
  if (process.env.NODE_ENV === 'dev' && canSkipCompile()) {
    console.info('COMPILATION SKIPPED: No changes detected in tracker dependencies')
    return
  }

  const bundledCode = await bundleCode()

  const startTime = Date.now();
  console.log(`Starting compilation of ${ALL_VARIANTS.length} variants...`)

  const bar = new progress.SingleBar({ clearOnComplete: true }, progress.Presets.shades_classic)
  bar.start(ALL_VARIANTS.length, 0)

  const workerPool = Pool(() => spawn(new Worker('./worker-thread.js')))
  ALL_VARIANTS.forEach(variant => {
    workerPool.queue(async (worker) => {
      await worker.compileFile(variant, { ...options, bundledCode })
      bar.increment()
    })
  })

  await workerPool.completed()
  await workerPool.terminate()
  bar.stop()

  console.log(`Completed compilation of ${ALL_VARIANTS.length} variants in ${((Date.now() - startTime) / 1000).toFixed(2)}s`);
}

export async function compileFile(variant, options) {
  const globals = { ...DEFAULT_GLOBALS, ...variant.globals }
  let code

  if (variant.entry_point) {
    code = await bundleCode(variant.entry_point)
  } else {
    code = options.bundledCode || await bundleCode()
  }

  if (!variant.npm_package) {
    code = wrapInstantlyEvaluatingFunction(code)
  }

  code = minify(code, globals, variant)

  if (variant.npm_package) {
    code = addExports(code)
  }

  if (options.returnCode) {
    return code
  } else {
    fs.writeFileSync(outputPath(variant, options), code)
  }
}

function wrapInstantlyEvaluatingFunction(baseCode) {
  return `(function(){${baseCode}})()`
}

// Works around minification limitation of swc not allowing exports
function addExports(code) {
  return `${code}\nexport { init, track, DEFAULT_FILE_TYPES }`
}

export function compileWebSnippet() {
  const code = fs.readFileSync(relPath('../src/web-snippet.js')).toString()
  return `
<script>
  ${minify(code)}
  plausible.init()
</script>
  `
}

async function bundleCode(entryPoint = 'src/plausible.js') {
  const bundle = await rollup({
    input: entryPoint,
    plugins: [json({compact: true})]
  })

  const { output } = await bundle.generate({ format: 'esm' })

  return output[0].code
}

function outputPath(variant, options) {
  if (variant.output_path) {
    return relPath(`../../${variant.output_path}${options.suffix || ""}`)
  } else if (variant.npm_package) {
    return relPath(`../${variant.name}${options.suffix || ""}`)
  } else {
    return relPath(`../../priv/tracker/js/${variant.name}${options.suffix || ""}`)
  }
}

function minify(code, globals, variant = {}) {
  const minifyOptions = {
    compress: {
      global_defs: globals,
      passes: 4
    },
    mangle: {}
  }

  if (variant.npm_package) {
    minifyOptions.mangle.reserved = ['init', 'track', 'DEFAULT_FILE_TYPES']
    minifyOptions.mangle.toplevel = true
  }

  const result = minifySync(code, minifyOptions)

  if (result.code) {
    return result.code
  } else {
    throw result.error
  }
}

function relPath(segment) {
  return path.join(__dirname, segment)
}
