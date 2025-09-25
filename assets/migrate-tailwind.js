#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

class TailwindMigrator {
  constructor(options = {}) {
    this.dryRun = options.dryRun || false;
    this.verbose = options.verbose || false;
    this.backup = options.backup !== false; // default true
    this.changedFiles = [];
    this.totalTransformations = 0;
    this.transformationLog = [];
  }

  log(message, level = 'info') {
    if (this.verbose || level === 'error') {
      console.log(`[${level.toUpperCase()}] ${message}`);
    }
  }

  logTransformation(file, original, transformed, type) {
    this.transformationLog.push({
      file,
      original,
      transformed,
      type,
      timestamp: new Date().toISOString()
    });
    this.totalTransformations++;

    if (this.verbose) {
      this.log(`${type}: "${original}" → "${transformed}" in ${file}`);
    }
  }

  transformOpacityClasses(content, filePath) {
    const opacityPrefixes = ['bg', 'text', 'border', 'ring', 'divide', 'placeholder'];

    // Find all className attributes, template literals, and props that likely contain Tailwind classes
    const classPatterns = [
      /className=["'`]([^"'`]*?)["'`]/g,
      /class=["'`]([^"'`]*?)["'`]/g,
      /\bclass\s*:\s*["'`]([^"'`]*?)["'`]/g, // CSS-in-JS or object syntax
      /\$\{[^}]*?["'`]([^"'`]*?)["'`][^}]*?\}/g, // Template literals with quotes
      /\{`([^`]*?)`\}/g, // Template literals in JSX props like bg={`...`}
      /=\{`([^`]*?)`\}/g, // JSX prop template literals
      // Generic pattern for any prop that looks like it contains Tailwind classes
      // Exclude common CSS properties like style, but include props that likely contain Tailwind classes
      /\b(?!style\b)[a-zA-Z][a-zA-Z0-9]*(?:Class|Style|Styles)?=["'`]([^"'`]*?(?:bg-|text-|border-|ring-|divide-|placeholder-|flex-|rounded|shadow|blur|outline-|drop-shadow)[^"'`]*?)["'`]/g
    ];

    let transformedContent = content;

    classPatterns.forEach(pattern => {
      transformedContent = transformedContent.replace(pattern, (match, classString) => {
        const transformedClasses = this.transformClassString(classString, filePath);
        if (transformedClasses !== classString) {
          this.logTransformation(filePath, classString, transformedClasses, 'opacity-classes');
        }
        return match.replace(classString, transformedClasses);
      });
    });

    return transformedContent;
  }

  transformClassString(classString, filePath) {
    const classes = classString.split(/\s+/).filter(Boolean);
    const result = [];
    const processed = new Set();

    for (let i = 0; i < classes.length; i++) {
      const cls = classes[i];

      if (processed.has(cls)) continue;

      // Parse variant prefix (dark:, hover:, sm:, etc.) and base class
      const variantMatch = cls.match(/^((?:[a-z-]+:)*)(.+)$/);
      const variants = variantMatch[1] || '';
      const baseClass = variantMatch[2];

      // Check if the base class is a color class that might have a corresponding opacity
      const colorMatch = baseClass.match(/^(bg|text|border|ring|divide|placeholder)-(.+)$/);

      if (colorMatch) {
        const [, prefix, colorPart] = colorMatch;

        // Look for corresponding opacity class with the same variants
        const opacityPattern = `${variants}${prefix}-opacity-`;
        const opacityClass = classes.find(c => c.startsWith(opacityPattern) && !processed.has(c));

        if (opacityClass) {
          const opacity = opacityClass.replace(opacityPattern, '');
          // Create new format: variants + prefix-color/opacity
          result.push(`${variants}${prefix}-${colorPart}/${opacity}`);
          processed.add(cls);
          processed.add(opacityClass);
          continue;
        }
      }

      // Check if it's a standalone opacity class (should be removed/warned)
      const standaloneOpacityMatch = cls.match(/^((?:[a-z-]+:)*)(bg|text|border|ring|divide|placeholder)-opacity-(\d+)$/);
      if (standaloneOpacityMatch) {
        // Skip standalone opacity classes - they should be combined with colors
        processed.add(cls);
        this.log(`Warning: Found standalone opacity class "${cls}" in ${filePath} - this may need manual review`, 'warning');
        continue;
      }

      // Keep the class as-is
      result.push(cls);
      processed.add(cls);
    }

    return result.join(' ');
  }

  transformSimpleReplacements(content, filePath) {
    // Find all className attributes, template literals, and props that likely contain Tailwind classes
    const classPatterns = [
      /className=["'`]([^"'`]*?)["'`]/g,
      /class=["'`]([^"'`]*?)["'`]/g,
      /\bclass\s*:\s*["'`]([^"'`]*?)["'`]/g, // CSS-in-JS or object syntax
      /\$\{[^}]*?["'`]([^"'`]*?)["'`][^}]*?\}/g, // Template literals with quotes
      /\{`([^`]*?)`\}/g, // Template literals in JSX props like bg={`...`}
      /=\{`([^`]*?)`\}/g, // JSX prop template literals
      // Generic pattern for any prop that looks like it contains Tailwind classes
      // Exclude common CSS properties like style, but include props that likely contain Tailwind classes
      /\b(?!style\b)[a-zA-Z][a-zA-Z0-9]*(?:Class|Style|Styles)?=["'`]([^"'`]*?(?:bg-|text-|border-|ring-|divide-|placeholder-|flex-|rounded|shadow|blur|outline-|drop-shadow)[^"'`]*?)["'`]/g
    ];

    // Define all the simple class replacements from Tailwind v3 to v4
    const replacements = [
      // Flex utilities
      { pattern: /\bflex-shrink-(\d+)\b/g, replacement: 'shrink-$1', type: 'flex-shrink' },
      { pattern: /\bflex-grow-(\d+)\b/g, replacement: 'grow-$1', type: 'flex-grow' },
      { pattern: /\bflex-grow\b/g, replacement: 'grow', type: 'flex-grow' },

      // Other renamed utilities
      { pattern: /\boverflow-ellipsis\b/g, replacement: 'text-ellipsis', type: 'overflow' },
      { pattern: /\bdecoration-slice\b/g, replacement: 'box-decoration-slice', type: 'decoration' },
      { pattern: /\bdecoration-clone\b/g, replacement: 'box-decoration-clone', type: 'decoration' },

      // Shadow scale changes (be careful with word boundaries)
      { pattern: /\bshadow-sm\b/g, replacement: 'shadow-xs', type: 'shadow' },
      { pattern: /\bshadow\b(?!-)/g, replacement: 'shadow-sm', type: 'shadow' },
      { pattern: /\bdrop-shadow-sm\b/g, replacement: 'drop-shadow-xs', type: 'drop-shadow' },
      { pattern: /\bdrop-shadow\b(?!-)/g, replacement: 'drop-shadow-sm', type: 'drop-shadow' },

      // Blur scale changes
      { pattern: /\bblur-sm\b/g, replacement: 'blur-xs', type: 'blur' },
      { pattern: /\bblur\b(?!-)/g, replacement: 'blur-sm', type: 'blur' },
      { pattern: /\bbackdrop-blur-sm\b/g, replacement: 'backdrop-blur-xs', type: 'backdrop-blur' },
      { pattern: /\bbackdrop-blur\b(?!-)/g, replacement: 'backdrop-blur-sm', type: 'backdrop-blur' },

      // Border radius scale changes
      { pattern: /\brounded-sm\b/g, replacement: 'rounded-xs', type: 'rounded' },
      { pattern: /\brounded\b(?!-)/g, replacement: 'rounded-sm', type: 'rounded' },

      // Outline changes
      { pattern: /\boutline-none\b/g, replacement: 'outline-hidden', type: 'outline' }
    ];

    let transformedContent = content;

    classPatterns.forEach(pattern => {
      transformedContent = transformedContent.replace(pattern, (match, classString) => {
        let transformedClasses = classString;

        // Apply all simple replacements to this class string
        replacements.forEach(({ pattern: replacePattern, replacement, type }) => {
          const originalClasses = transformedClasses;
          transformedClasses = transformedClasses.replace(replacePattern, (match, ...args) => {
            // For most patterns, replacement is a string, but for patterns with groups, use the replacement pattern
            const actualReplacement = replacement.includes('$') ?
              match.replace(replacePattern, replacement) : replacement;

            this.logTransformation(filePath, match, actualReplacement, type);
            return actualReplacement;
          });
        });

        return match.replace(classString, transformedClasses);
      });
    });

    return transformedContent;
  }

  async processFile(filePath) {
    try {
      const originalContent = fs.readFileSync(filePath, 'utf8');
      let transformedContent = originalContent;

      // Apply all transformations
      transformedContent = this.transformOpacityClasses(transformedContent, filePath);
      transformedContent = this.transformSimpleReplacements(transformedContent, filePath);

      // Only write if content changed
      if (transformedContent !== originalContent) {
        if (!this.dryRun) {
          // Create backup if enabled
          if (this.backup) {
            const backupPath = `${filePath}.tw-backup`;
            fs.writeFileSync(backupPath, originalContent);
            this.log(`Created backup: ${backupPath}`);
          }

          fs.writeFileSync(filePath, transformedContent);
        }

        this.changedFiles.push(filePath);
        this.log(`${this.dryRun ? '[DRY RUN] ' : ''}Processed: ${filePath}`);
      }

      return true;
    } catch (error) {
      this.log(`Error processing ${filePath}: ${error.message}`, 'error');
      return false;
    }
  }

  async run(targetFile = null) {
    const startTime = Date.now();
    this.log('Starting Tailwind CSS v3 to v4 migration...');

    if (this.dryRun) {
      this.log('Running in DRY RUN mode - no files will be modified');
    }

    let allFiles = [];

    if (targetFile) {
      // Single file mode
      const resolvedPath = path.resolve(targetFile);
      if (!fs.existsSync(resolvedPath)) {
        this.log(`File not found: ${targetFile}`, 'error');
        return;
      }

      const ext = path.extname(resolvedPath);
      const supportedExtensions = ['.ts', '.tsx', '.js', '.ex', '.heex', '.eex', '.css'];

      if (!supportedExtensions.includes(ext)) {
        this.log(`Unsupported file extension: ${ext}. Supported: ${supportedExtensions.join(', ')}`, 'error');
        return;
      }

      allFiles.push(resolvedPath);
      this.log(`Processing single file: ${targetFile}`);
    } else {
      // Collect all files to process
      // Find JavaScript/TypeScript files
      this.findFiles(path.join(__dirname, 'js'), ['.ts', '.tsx', '.js'], allFiles);

      // Find Elixir template files
      const libPath = path.join(__dirname, '..', 'lib', 'plausible_web');
      if (fs.existsSync(libPath)) {
        this.findFiles(libPath, ['.ex', '.heex', '.eex'], allFiles);
      }

      // Find CSS files
      this.findFiles(path.join(__dirname, 'css'), ['.css'], allFiles);

      this.log(`Found ${allFiles.length} files to process`);
    }

    let processedCount = 0;
    let errorCount = 0;

    for (const file of allFiles) {
      const success = await this.processFile(file);
      if (success) {
        processedCount++;
      } else {
        errorCount++;
      }
    }

    const duration = Date.now() - startTime;
    this.printSummary(processedCount, errorCount, duration);
  }

  findFiles(dir, extensions, result) {
    if (!fs.existsSync(dir)) {
      return;
    }

    const items = fs.readdirSync(dir);
    for (const item of items) {
      const fullPath = path.join(dir, item);
      const stat = fs.statSync(fullPath);

      if (stat.isDirectory()) {
        // Skip node_modules and other common directories
        if (['node_modules', '.git', 'dist', 'build'].includes(item)) {
          continue;
        }
        this.findFiles(fullPath, extensions, result);
      } else if (stat.isFile()) {
        const ext = path.extname(fullPath);
        if (extensions.includes(ext)) {
          result.push(fullPath);
        }
      }
    }
  }

  printSummary(processedCount, errorCount, duration) {
    console.log('\n' + '='.repeat(60));
    console.log('TAILWIND MIGRATION SUMMARY');
    console.log('='.repeat(60));
    console.log(`Files processed: ${processedCount}`);
    console.log(`Files with changes: ${this.changedFiles.length}`);
    console.log(`Total transformations: ${this.totalTransformations}`);
    console.log(`Errors: ${errorCount}`);
    console.log(`Duration: ${duration}ms`);

    if (this.dryRun) {
      console.log('\n🔍 DRY RUN MODE - No files were actually modified');
      console.log('Run without --dry-run to apply changes');
    }

    if (this.changedFiles.length > 0) {
      console.log('\nFiles with changes:');
      this.changedFiles.forEach(file => console.log(`  • ${file}`));
    }

    if (this.backup && !this.dryRun && this.changedFiles.length > 0) {
      console.log('\n💾 Backup files created with .tw-backup extension');
      console.log('Remove them after verifying the migration worked correctly');
    }

    // Write detailed log
    if (this.transformationLog.length > 0) {
      const logPath = path.join(__dirname, 'tailwind-migration-log.json');
      fs.writeFileSync(logPath, JSON.stringify(this.transformationLog, null, 2));
      console.log(`\n📝 Detailed transformation log written to: ${logPath}`);
    }
  }
}

// CLI handling
function main() {
  const args = process.argv.slice(2);

  // Extract file path (non-option arguments)
  const fileArgs = args.filter(arg => !arg.startsWith('--') && !arg.startsWith('-'));
  const targetFile = fileArgs[0] || null;

  const options = {
    dryRun: args.includes('--dry-run'),
    verbose: args.includes('--verbose') || args.includes('-v'),
    backup: !args.includes('--no-backup')
  };

  if (args.includes('--help') || args.includes('-h')) {
    console.log(`
Tailwind CSS v3 to v4 Migration Tool

Usage: node migrate-tailwind.js [file] [options]

Arguments:
  file          Specific file to migrate (optional)

Options:
  --dry-run     Preview changes without modifying files
  --verbose, -v Show detailed transformation logs
  --no-backup   Skip creating backup files
  --help, -h    Show this help message

Examples:
  node migrate-tailwind.js --dry-run                    # Preview all changes
  node migrate-tailwind.js js/dashboard/index.tsx      # Process single file
  node migrate-tailwind.js file.tsx --dry-run          # Preview single file
  node migrate-tailwind.js --verbose                   # Run with detailed logs
`);
    process.exit(0);
  }

  const migrator = new TailwindMigrator(options);
  migrator.run(targetFile).catch(error => {
    console.error('Migration failed:', error);
    process.exit(1);
  });
}

if (require.main === module) {
  main();
}

module.exports = TailwindMigrator;
