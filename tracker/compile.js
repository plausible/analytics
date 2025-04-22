import { parseArgs } from 'node:util'
import { compileAll } from './compiler/index.js'

const { values, positionals } = parseArgs({
  options: {
    'target': {
      type: 'string',
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

compileAll({
  targets: parse(values.target),
  only: positionals ? positionals.map(parse) : null
})
