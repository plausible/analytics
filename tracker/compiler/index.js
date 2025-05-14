import uglify from 'uglify-js'
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
  const baseCode = getCode()

  const startTime = Date.now();
  console.log(`Starting compilation of ${variants.length} variants...`)

  const bar = new progress.SingleBar({ clearOnComplete: true }, progress.Presets.shades_classic)
  bar.start(variants.length, 0)

  const workerPool = Pool(() => spawn(new Worker('./worker-thread.js')))
  variants.forEach(variant => {
    workerPool.queue(async (worker) => {
      await worker.compileFile(variant, { ...options, baseCode })
      bar.increment()
    })
  })

  await workerPool.completed()
  await workerPool.terminate()
  bar.stop()

  console.log(`Completed compilation of ${variants.length} variants in ${((Date.now() - startTime) / 1000).toFixed(2)}s`);
}

export function compileFile(variant, options) {
  const baseCode = options.baseCode || getCode()
  const globals = { ...DEFAULT_GLOBALS, ...variant.globals }

  const code = minify(baseCode, globals)

  if (options.returnCode) {
    return code
  } else {
    fs.writeFileSync(relPath(`../../priv/tracker/js/${variant.name}${options.suffix || ""}`), code)
  }
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

function getCode() {
  // Wrap the code in an instantly evaluating function
  return `(function(){${fs.readFileSync(relPath('../src/plausible.js')).toString()}})()`
}

function minify(baseCode, globals) {
  const result = uglify.minify(baseCode, {
    compress: {
      global_defs: globals
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
