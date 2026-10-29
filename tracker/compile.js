import { parseArgs } from 'node:util'
import { compileAll, compileWebSnippet } from './compiler/index.js'
import { watch } from 'node:fs'

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

if (!values.watch) {
  await compileAll(compileOptions)
} else {
  console.log('Watching src/ directory for changes...')

  // fs.watch can fire several events for a single save, so recompile once they settle
  let timeout
  watch('./src', { recursive: true }, (_eventType, filename) => {
    if (filename) {
      clearTimeout(timeout)
      timeout = setTimeout(async () => {
        console.log(`\nFile changed: ${filename}`)
        console.log('Recompiling...')

        try {
          await compileAll(compileOptions)
          console.log('Done. Watching for changes...')
        } catch (e) {
          console.error(
            new Error('Failed to compile all. Watching for changes...', {
              cause: e
            })
          )
        }
      }, 100)
    }
  })
}
