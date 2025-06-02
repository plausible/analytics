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

const __dirname = path.dirname(fileURLToPath(import.meta.url))

const DEFAULT_GLOBALS = {
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

export async function compileAll(options = {}) {
  if (process.env.NODE_ENV === 'dev' && canSkipCompile()) {
    console.info('COMPILATION SKIPPED: No changes detected in tracker dependencies')
    return
  }

  const variants = getVariantsToCompile(options)
  const bundledCode = await bundleCode()

  const startTime = Date.now();
  console.log(`Starting compilation of ${variants.length} variants...`)

  const bar = new progress.SingleBar({ clearOnComplete: true }, progress.Presets.shades_classic)
  bar.start(variants.length, 0)

  const workerPool = Pool(() => spawn(new Worker('./worker-thread.js')))
  variants.forEach(variant => {
    workerPool.queue(async (worker) => {
      await worker.compileFile(variant, { ...options, bundledCode })
      bar.increment()
    })
  })

  await workerPool.completed()
  await workerPool.terminate()
  bar.stop()

  console.log(`Completed compilation of ${variants.length} variants in ${((Date.now() - startTime) / 1000).toFixed(2)}s`);
}

export async function compileFile(variant, options) {
  const globals = { ...DEFAULT_GLOBALS, ...variant.globals }
  const bundledCode = options.bundledCode || await bundleCode()
  const minifiedCode = minify(bundledCode, globals, variant)
  const code = wrapCode(minifiedCode, variant)

  if (options.returnCode) {
    return code
  } else {
    fs.writeFileSync(outputPath(variant, options), code)
  }
}

function wrapCode(bundledCode, variant) {
  switch (variant.npm_package) {
    case 'esm':
      return `${bundledCode}\nexport { init, track }`
    default:
      // Legacy variants wrap in an immediately-evaluating function
      return `(function(){${bundledCode}})()`
  }
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

function getVariantsToCompile(options) {
  let targetVariants = variantsFile.legacyVariants.concat(variantsFile.manualVariants)
  if (options.targets !== null) {
    targetVariants = targetVariants.filter(variant =>
      options.targets.every(target => variant.compileIds.includes(target))
    )
  }
  if (options.only !== null) {
    targetVariants = targetVariants.filter(variant =>
      options.only.some(targetCompileIds => equalLists(variant.compileIds, targetCompileIds))
    )
  }

  return targetVariants
}

async function bundleCode(format = 'esm') {
  const bundle = await rollup({
    input: 'src/plausible.js',
  })

  const { output } = await bundle.generate({ format })

  return output[0].code
}

function outputPath(variant, options) {
  if (variant.npm_package) {
    return relPath(`../${variant.name}${options.suffix || ""}`)
  } else {
    return relPath(`../../priv/tracker/js/${variant.name}${options.suffix || ""}`)
  }
}

function minify(code, globals, variant = {}) {
  const minifyOptions = {
    compress: {
      global_defs: globals
    }
  }

  if (variant.npm_package) {
    minifyOptions.mangle = false
  } else {
    minifyOptions.compress.passes = 4
  }

  const result = minifySync(code, minifyOptions)

  return readOutput(result)
}

function readOutput(result) {
  if (result.code) {
    return result.code
  } else {
    throw result.error
  }
}

function equalLists(a, b) {
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
