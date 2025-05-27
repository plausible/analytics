import { defineConfig } from 'eslint/config'
import globals from 'globals'
import pluginJs from '@eslint/js'
import pluginPlaywright from 'eslint-plugin-playwright'
import prettierEslintInteroperabilityConfig from 'eslint-config-prettier/flat'
import { DEFAULT_GLOBALS as COMPILER_GLOBALS } from './compiler/index.js'

export const ALLOWED_COMPILER_GLOBALS = Object.fromEntries(
  Object.entries(COMPILER_GLOBALS).map(([global]) => [global, 'readonly'])
)

// Assume that window.plausible is accessible within script
export const NON_BOOLEAN_SCRIPT_GLOBALS = {
  plausible: false
}

export default defineConfig([
  {
    files: ['**/*.{js,ts,jsx,tsx}'],
    plugins: { js: pluginJs },
    extends: ['js/recommended']
  },
  {
    files: ['src/**/*.js'],
    languageOptions: {
      globals: {
        ...globals.browser,
        ...ALLOWED_COMPILER_GLOBALS,
        ...NON_BOOLEAN_SCRIPT_GLOBALS
      },
      ecmaVersion: 5,
      sourceType: 'script'
    }
  },
  {
    files: ['test/**/*.js'],
    ...pluginPlaywright.configs['flat/recommended'],
    languageOptions: {
      globals: {
        // available in test runner:
        ...globals.node,
        // available within the Page under test:
        ...globals.browser,
        ...NON_BOOLEAN_SCRIPT_GLOBALS
      }
    },
    rules: {
      ...pluginPlaywright.configs['flat/recommended'].rules,
      'playwright/expect-expect': 'off',
      'playwright/no-wait-for-selector': 'off',
      'playwright/no-wait-for-timeout': 'off'
    }
  },
  {
    files: [
      'compile.js',
      'compiler/**/*.js',
      'playwright.config.js',
      'eslint.config.mjs',
      'test/support/server.js'
    ],
    languageOptions: { globals: globals.node, ecmaVersion: 'latest' }
  },
  prettierEslintInteroperabilityConfig
])
