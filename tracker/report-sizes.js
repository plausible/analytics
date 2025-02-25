const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const PrivTrackerDir = '../priv/tracker/js/';

const toReport = [
  'plausible.js',
  'plausible.compat.js',
  'plausible.manual.js',
  'plausible.hash.js'
];

const results = [];

toReport.forEach((filename) => {
  const filePath = path.join(PrivTrackerDir, filename);
  if (fs.statSync(filePath).isFile()) {
    results.push({
      'Filename': filename,
      'Real Size (Bytes)': fs.statSync(filePath).size,
      'Gzipped Size (Bytes)': execSync(`gzip -c -9 "${filePath}"`).length,
      'Brotli Size (Bytes)': execSync(`brotli -c -q 11 "${filePath}"`).length
    });
  }
});

console.table(results)
