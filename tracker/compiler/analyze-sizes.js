/*
This script analyzes the size changes of tracker script variants across different versions and git branches.

Requires clickhouse-local to be installed.

To run it:
- Switch to the desired baseline branch
- Run `node compile.js --suffix baseline`
- Switch to the current branch
- Run `node compile.js --suffix current`
- Run `node compiler/analyze-sizes.js --baselineSuffix baseline --currentSuffix current`

It will output tables outlining tracker script size changes.
*/

import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import { execSync } from 'child_process'
import { parseArgs } from 'node:util'
import { markdownTable } from 'markdown-table'
import variantsFile from './variants.json' with { type: 'json' }

const { values } = parseArgs({
  options: {
    'help': {
      type: 'boolean',
    },
    'currentSuffix': {
      type: 'string',
      default: 'current'
    },
    'baselineSuffix': {
      type: 'string',
      default: 'master'
    },
    'usePreviousData': {
      type: 'boolean',
      default: false
    }
  }
})

const { currentSuffix, baselineSuffix } = values
const __dirname = path.dirname(fileURLToPath(import.meta.url))
const TRACKER_FILES_DIR = path.join(__dirname, "../../priv/tracker/js/")

const HEADER = ['', 'Brotli', 'Gzip', 'Uncompressed']

if (values.help) {
  console.log('Usage: node analyze-sizes.js master current')
  console.log('Options:')
  console.log('  --help               Show this help message')
  console.log('  --currentSuffix      The suffix of the current script variants (see suffix flag for compile.js). Default: current')
  console.log('  --baselineSuffix     The suffix of the previous script variants (see suffix flag for compile.js). Default: master')
  console.log('  --usePreviousData    Use data from a previous run, speeding up the analysis.')
  process.exit(0);
}


let fileData
if (values.usePreviousData) {
  fileData = JSON.parse(fs.readFileSync(path.join(__dirname, '.analyze-sizes.json'), 'utf8'))
} else {
  fileData = readPlausibleScriptSizes()
  fs.writeFileSync(path.join(__dirname, '.analyze-sizes.json'), JSON.stringify(fileData))
}

const manualVariants = variantsFile.manualVariants.map((variant) => `'${variant.name}'`).join(', ')
const ctes = `
WITH
  array(${manualVariants}) as manual_variants,
  array(
    'plausible.js',
    'plausible.hash.js',
    'plausible.pageview-props.tagged-events.js',
    'plausible.file-downloads.hash.pageview-props.revenue.js',
    'plausible.compat.exclusions.file-downloads.outbound-links.pageview-props.revenue.tagged-events.js'
  ) as important_variants,
  data AS (
    SELECT
      variant,
      not has(manual_variants, variant) as is_legacy_variant,
      sumIf(uncompressed, suffix = '${baselineSuffix}') as baseline_uncompressed,
      sumIf(gzip, suffix = '${baselineSuffix}') as baseline_gzip,
      sumIf(brotli, suffix = '${baselineSuffix}') as baseline_brotli,
      sumIf(uncompressed, suffix = '${currentSuffix}') as current_uncompressed,
      sumIf(gzip, suffix = '${currentSuffix}') as current_gzip,
      sumIf(brotli, suffix = '${currentSuffix}') as current_brotli,
      current_uncompressed - baseline_uncompressed as uncompressed_increase,
      current_gzip - baseline_gzip as gzip_increase,
      current_brotli - baseline_brotli as brotli_increase,
      ifNotFinite((current_uncompressed / baseline_uncompressed - 1.0) * 100.0, NULL) as uncompressed_increase_percentage,
      ifNotFinite((current_gzip / baseline_gzip - 1.0) * 100.0, NULL) as gzip_increase_percentage,
      ifNotFinite((current_brotli / baseline_brotli - 1.0) * 100.0, NULL) as brotli_increase_percentage
    FROM table
    GROUP BY variant
  )
`

const mainVariantResults = clickhouseLocal(`
  ${ctes}
  SELECT *
  FROM data
  WHERE not is_legacy_variant
  ORDER BY variant
`, fileData)

const legacyVariantResults = clickhouseLocal(`
  ${ctes}
  SELECT *
  FROM data
  WHERE is_legacy_variant AND has(important_variants, variant)
  ORDER BY length(variant)
`, fileData)

const rowAsMap = `
map(
  'variant', variant,
  'baseline_uncompressed', toString(baseline_uncompressed),
  'baseline_gzip', toString(baseline_gzip),
  'baseline_brotli', toString(baseline_brotli),
  'current_uncompressed', toString(current_uncompressed),
  'current_gzip', toString(current_gzip),
  'current_brotli', toString(current_brotli),
  'uncompressed_increase', toString(uncompressed_increase),
  'gzip_increase', toString(gzip_increase),
  'brotli_increase', toString(brotli_increase),
  'uncompressed_increase_percentage', toString(uncompressed_increase_percentage),
  'gzip_increase_percentage', toString(gzip_increase_percentage),
  'brotli_increase_percentage', toString(brotli_increase_percentage)
)
`

const [summary] = clickhouseLocal(`
  ${ctes}
  SELECT
    count() AS total_variants,
    countIf(brotli_increase_percentage > 0.0) AS brotli_increase_percentaged_variants,
    countIf(brotli_increase_percentage < 0.0) AS brotli_decreased_variants,
    argMax(
      ${rowAsMap},
      brotli_increase_percentage
    ) AS max_increase_variant,
    argMin(
      ${rowAsMap},
      brotli_increase_percentage
    ) AS min_increase_variant,
    argMaxIf(
      ${rowAsMap},
      current_brotli,
      is_legacy_variant
    ) AS largest_variant,
    map(
      'variant', 'Median change',
      'baseline_uncompressed', toString(median(baseline_uncompressed)),
      'baseline_gzip', toString(median(baseline_gzip)),
      'baseline_brotli', toString(median(baseline_brotli)),
      'current_uncompressed', toString(median(current_uncompressed)),
      'current_gzip', toString(median(current_gzip)),
      'current_brotli', toString(median(current_brotli)),
      'uncompressed_increase', toString(median(uncompressed_increase)),
      'gzip_increase', toString(median(gzip_increase)),
      'brotli_increase', toString(median(brotli_increase)),
      'uncompressed_increase_percentage', toString(median(uncompressed_increase_percentage)),
      'gzip_increase_percentage', toString(median(gzip_increase_percentage)),
      'brotli_increase_percentage', toString(median(brotli_increase_percentage))
    ) AS median_result
  FROM data
`, fileData)

console.log(`Analyzed ${summary.total_variants} tracker script variants for size changes.`)
console.log(`The following tables summarize the results, with comparison with the baseline version in parentheses.\n`)

console.log("Main variants:")
console.log(createMarkdownTable(mainVariantResults))

console.log("\nImportant legacy variants:")
console.log(createMarkdownTable(legacyVariantResults))

console.log("\nSummary:")
console.log(createMarkdownTable([
  { ...summary.largest_variant, variant: `Largest variant (${summary.largest_variant.variant})`},
  { ...summary.max_increase_variant, variant: `Max change (${summary.max_increase_variant.variant})`},
  { ...summary.min_increase_variant, variant: `Min change (${summary.min_increase_variant.variant})`},
  summary.median_result
]))

console.log(`\nIn total, ${summary.brotli_increase_percentaged_variants} variants brotli size increased and ${summary.brotli_decreased_variants} variants brotli size decreased.`)

function createMarkdownTable(rows) {
  return markdownTable([HEADER].concat(rows.map(markdownRow)))
}

function markdownRow(row) {
  if (Array.isArray(row)) {
    return row
  }

  const isNew = row.baseline_uncompressed === null

  return [
    isNew ? `${row.variant} (new variant)` : row.variant,
    sizeColumn(row, 'brotli'),
    sizeColumn(row, 'gzip'),
    sizeColumn(row, 'uncompressed')
  ]
}


function sizeColumn(row, key) {
  const currentSize = row[`current_${key}`]
  const previousIncrease = row[`${key}_increase`]
  const increasePercentage = row[`${key}_increase_percentage`]
  if (previousIncrease === null) {
    return `${currentSize}B`
  } else {
    return `${currentSize}B (${addSign(previousIncrease)}B / ${formatPercentage(increasePercentage)})`
  }
}

function formatPercentage(value) {
  const prefix = +value > 0 ? '+' : ''
  return `${prefix}${Math.round(+value * 10) / 10}%`
}

function addSign(value) {
  return +value > 0 ? `+${value}` : +value
}

function readPlausibleScriptSizes() {
  const files = fs.readdirSync(TRACKER_FILES_DIR).filter((filename) =>
    !['.gitkeep', 'p.js'].includes(filename) && (filename.includes(currentSuffix) || filename.includes(baselineSuffix))
  )

  return files.map((filename) => {
    const filePath = path.join(TRACKER_FILES_DIR, filename)
    const [_, variant, suffix] = /(.*)[.]js(.*)/.exec(filename)
    return {
      variant: `${variant}.js`,
      suffix,
      uncompressed: fs.statSync(filePath).size,
      gzip: execSync(`gzip -c -9 "${filePath}"`).length,
      brotli: execSync(`brotli -c -q 11 "${filePath}"`).length
    }
  })
}

function clickhouseLocal(sql, inputLines = null) {
  const options = {}
  if (inputLines) {
    options.input = inputLines.map(JSON.stringify).join("\n")
  }

  const result = execSync(`clickhouse-local --query="${sql}" --format=JSON ${inputLines ? "--input-format=JSONLines" : ""}`, options)
  const json = JSON.parse(result.toString())

  return json.data
}
