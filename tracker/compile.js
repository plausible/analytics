import { parseArgs } from 'node:util'
import { compileAll, compileWebSnippet } from './compiler/index.js'
import chokidar from 'chokidar'

const { values } = parseArgs({
  options: {
    watch: {
      type: 'boolean',
      short: 'w'
    },
    help: {
      type: 'boolean'
    },
    suffix: {
      type: 'string',
      default: ''
    },
    'web-snippet': {
      type: 'boolean'
    }
  }
})

if (values.help) {
  console.log('Usage: node compile.js [flags]')
  console.log('Options:')
  console.log(
    '  --watch, -w                               Watch src/ directory for changes and recompile'
  )
  console.log(
    '  --suffix, -s                              Suffix to add to the output file name. Used for testing script size changes'
  )
  console.log(
    '  --help                                    Show this help message'
  )
  console.log(
    '  --web-snippet                             Compile and output the web snippet'
  )
  process.exit(0)
}

if (values['web-snippet']) {
  console.log(compileWebSnippet())
  process.exit(0)
}

const compileOptions = {
  suffix: values.suffix
}

await compileAll(compileOptions)

if (values.watch) {
  console.log('Watching src/ directory for changes...')

  chokidar.watch('./src').on('change', async (_event, path) => {
    if (path) {
      console.log(`\nFile changed: ${path}`)
      console.log('Recompiling...')

      await compileAll(compileOptions)

      console.log('Done. Watching for changes...')
    }
  })
}
