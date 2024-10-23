const fs = require('fs');
const path = require('path');

const SRC_DIR = path.join(__dirname, '../src');
const COPY_DIR = path.join(__dirname, 'src-copies');

// Re-compilation is only required if any of these files have been changed. 
const SRC_FILES = ['customEvents.js', 'plausible.js'];

/**
 * Returns a boolean indicating whether the tracker compilation can be skipped.
 * This is verified by storing copies of source files and comparing them with
 * the current contents of those files every time `compile.js` gets executed.
 */
exports.canSkipCompile = function() {
  let canSkip = true

  SRC_FILES.forEach((file) => {
    const originalPath = path.join(SRC_DIR, file)
    const copyPath = path.join(COPY_DIR, file)

    const original = fs.readFileSync(originalPath).toString()
    const copyExists = fs.existsSync(copyPath)

    if (!copyExists) {
      canSkip = false
      !fs.existsSync(COPY_DIR) && fs.mkdirSync(COPY_DIR)
      fs.writeFileSync(copyPath, original)
    } else if (original !== fs.readFileSync(copyPath).toString()) {
      canSkip = false
      fs.writeFileSync(copyPath, original)
    }
  })

  return canSkip
}