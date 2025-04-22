const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const LAST_HASH_FILEPATH = path.join(__dirname, './last-hash.txt')

// Re-compilation is only required if any of these files have been changed.
const COMPILE_DEPENDENCIES = [
  path.join(__dirname, '../compile.js'),
  path.join(__dirname, '../src/plausible.js'),
  path.join(__dirname, '../src/customEvents.js')
]

function currentHash() {
  const combinedHash = crypto.createHash('sha256');

  for (const filePath of COMPILE_DEPENDENCIES) {
    try {
      const fileContent = fs.readFileSync(filePath);
      const fileHash = crypto.createHash('sha256').update(fileContent).digest();
      combinedHash.update(fileHash);
    } catch (error) {
      throw new Error(`Failed to read or hash ${filePath}: ${error.message}`);
    }
  }

  return combinedHash.digest('hex');
}

function lastHash() {
  if (fs.existsSync(LAST_HASH_FILEPATH)) {
    return fs.readFileSync(LAST_HASH_FILEPATH).toString()
  }
}

/**
 * Returns a boolean indicating whether the tracker compilation can be skipped.
 * Every time this function gets executed, the hash of the tracker dependencies
 * will be updated. Compilation can be skipped if the hash hasn't changed since
 * the last execution.
 */
exports.canSkipCompile = function() {
  const current = currentHash()
  const last = lastHash()

  if (current === last) {
    return true
  } else {
    fs.writeFileSync(LAST_HASH_FILEPATH, current)
    return false
  }
}
