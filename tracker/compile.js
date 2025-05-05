import { parseArgs } from 'node:util'
import { compileAll } from './compiler/index.js'
import chokidar from 'chokidar'

const { values, positionals } = parseArgs({
  options: {
    'target': {
      type: 'string',
    },
    'watch': {
      type: 'boolean',
      short: 'w'
    },
    'help': {
      type: 'boolean',
    },
    'suffix': {
      type: 'string',
      default: ''
    }
  },
  allowPositionals: true
})

if (values.help) {
  console.log('Usage: node compile.js [...compile-ids] [flags]')
  console.log('Options:')
  console.log('  --target hash,outbound-links,exclusions   Only compile variants that contain all specified features')
  console.log('  --watch, -w                               Watch src/ directory for changes and recompile')
  console.log('  --suffix, -s                              Suffix to add to the output file name. Used for testing script size changes')
  console.log('  --help                                    Show this help message')
  process.exit(0);
}

function parse(value) {
  if (value == null) {
    return null
  }

  return value
    .split(/[.,]/)
    .filter(feature => !['js', 'plausible'].includes(feature))
    .sort()
}

const compileOptions = {
  targets: parse(values.target),
  only: positionals && positionals.length > 0 ? positionals.map(parse) : null,
  suffix: values.suffix
}

await compileAll(compileOptions)

if (values.watch) {
  console.log('Watching src/ directory for changes...')

  chokidar.watch('./src').on('change', async (event, path) => {
    if (path) {
      console.log(`\nFile changed: ${path}`)
      console.log('Recompiling...')

      await compileAll(compileOptions)

      console.log('Done. Watching for changes...')
    }
  })
}
