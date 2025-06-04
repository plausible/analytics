import { minifySync as swcMinify } from '@swc/core'
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
  COMPILE_CONFIG: false
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
  const wrappedCode = wrapInstantlyEvaluatingFunction(options.bundledCode || await bundleCode())
  const globals = { ...DEFAULT_GLOBALS, ...variant.globals }

  const code = minify(wrappedCode, globals)

  if (options.returnCode) {
    return code
  } else {
    fs.writeFileSync(relPath(`../../priv/tracker/js/${variant.name}${options.suffix || ""}`), code)
  }
}

function wrapInstantlyEvaluatingFunction(baseCode) {
  return `(function(){${baseCode}})()`
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

async function bundleCode() {
  const bundle = await rollup({
    input: 'src/plausible.js',
  })

  const { output } = await bundle.generate({
    format: 'esm',
  })

  return output[0].code
}

function minify(baseCode, globals) {
  const result = swcMinify(baseCode, {
    compress: {
      global_defs: globals,
      passes: 4
    }
  })

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
