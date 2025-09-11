import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import g from 'generatorics'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

function idToGlobal(id) {
  return `COMPILE_${id.replace('-', '_').toUpperCase()}`
}

const LEGACY_VARIANT_NAMES = [
  'hash',
  'outbound-links',
  'exclusions',
  'compat',
  'local',
  'manual',
  'file-downloads',
  'pageview-props',
  'tagged-events',
  'revenue'
]
let legacyVariants = [...g.clone.powerSet(LEGACY_VARIANT_NAMES)]
  .map((a) => a.sort())
  .map((variant) => ({
    name:
      variant.length > 0 ? `plausible.${variant.join('.')}.js` : 'plausible.js',
    globals: {
      ...Object.fromEntries(variant.map((id) => [idToGlobal(id), true])),
      COMPILE_PLAUSIBLE_LEGACY_VARIANT: true
    }
  }))

const variantsFile = path.join(__dirname, 'variants.json')
const existingData = JSON.parse(fs.readFileSync(variantsFile, 'utf8'))

fs.writeFileSync(
  variantsFile,
  JSON.stringify({ ...existingData, legacyVariants }, null, 2) + '\n'
)
