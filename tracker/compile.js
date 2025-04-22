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
    }
  },
  allowPositionals: true
})

if (values.help) {
  console.log('Usage: node compile.js [options]')
  console.log('Options:')
  console.log('  --target hash,outbound-links,exclusions   Only compile variants that contain all specified features')
  console.log('  --only hash,outbound-links,exclusions     Only compile a specific variant')
  console.log('  --watch, -w                               Watch src/ directory for changes and recompile')
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
  only: positionals ? positionals.map(parse) : null
}

compileAll(compileOptions)

if (values.watch) {
  console.log('Watching src/ directory for changes...')

  chokidar.watch('./src').on('change', (event, path) => {
    if (path) {
      console.log(`\nFile changed: ${path}`)
      console.log('Recompiling...')

      compileAll(compileOptions)

      console.log('Done. Watching for changes...')
    }
  })
}
