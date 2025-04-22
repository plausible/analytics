const fs = require('fs')
const path = require('path')
const g = require("generatorics");

const base_variants = ["hash", "outbound-links", "exclusions", "compat", "local", "manual", "file-downloads", "pageview-props", "tagged-events", "revenue"]
let variants = [...g.clone.powerSet(base_variants)]
  .map(a => a.sort())
  .map((variant) => ({
    name: variant.length > 0 ? `plausible.${variant.join('.')}.js` : 'plausible.js',
    features: variant
  }))

fs.writeFileSync(path.join(__dirname, 'variants.json'), JSON.stringify({ variants }, null, 2))
