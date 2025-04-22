import { parseArgs } from 'node:util'
import { compileAll } from './compiler/index.js'

const { values } = parseArgs({
  options: {
    'target': {
      type: 'string',
    },
    'help': {
      type: 'boolean',
    }
  }
})

if (values.help) {
  console.log('Usage: node compile.js [options]');
  console.log('Options:');
  console.log('  --target hash,outbound-links,exclusions   Only compile variants that contain all specified features');
  console.log('  --help                                    Show this help message');
  process.exit(0);
}

compileAll({ targets: values.target ? values.target.split(',') : null })
