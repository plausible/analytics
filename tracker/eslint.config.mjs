import globals from 'globals'
import { globalIgnores } from 'eslint/config'
import eslint from '@eslint/js'
import pluginPlaywright from 'eslint-plugin-playwright'
import prettierEslintInteroperabilityConfig from 'eslint-config-prettier/flat'
import tseslint from 'typescript-eslint'
import { DEFAULT_GLOBALS } from './compiler/index.js'

const DEFAULT_BOOLEAN_SETTINGS = Object.fromEntries(
  Object.entries(DEFAULT_GLOBALS).map(([global]) => [global, 'readonly'])
)

export default tseslint.config([
  globalIgnores(['./npm_package/plausible.js']),
  // shared config for all files
  eslint.configs.recommended,
  tseslint.configs.recommended,
  {
    rules: {
      '@typescript-eslint/no-unused-vars': [
        'error',
        {
          argsIgnorePattern: '^_',
          varsIgnorePattern: '^_',
          caughtErrorsIgnorePattern: '^_'
        }
      ],
      '@typescript-eslint/no-unused-expressions': [
        'error',
        {
          allowShortCircuit: true
        }
      ]
    }
  },
  // config for build scripts
  {
    files: [
      'compile.js',
      'compiler/**/*.js',
      'playwright.config.js',
      'eslint.config.mjs',
      'playwright.config.ts',
      'test/support/server.js'
    ],
    languageOptions: { ecmaVersion: 'latest', globals: globals.node }
  },
  // config for tracker script
  {
    files: ['src/**/*.js'],
    languageOptions: {
      ecmaVersion: 5, // must work also in older browsers
      globals: {
        ...globals.browser,
        ...DEFAULT_BOOLEAN_SETTINGS,
        plausible: 'writeable'
      },
      sourceType: 'commonjs'
    }
  },
  // config for installation support scripts
  {
    files: ['installation_support/**/*.js'],
    languageOptions: {
      ecmaVersion: 'latest', // must work only in modern browsers
      globals: {
        ...globals.browser,
        plausible: 'readable'
      }
    }
  },
  // config for tests of tracker scripts and installation support scripts
  {
    files: ['test/**/*.js', 'test/**/*.ts'],
    ...pluginPlaywright.configs['flat/recommended'],
    languageOptions: {
      ecmaVersion: 'latest',
      globals: {
        // available in test runner:
        ...globals.node,
        // available within the Page under test:
        ...globals.browser,
        plausible: 'readable'
      }
    },
    rules: {
      ...pluginPlaywright.configs['flat/recommended'].rules,
      'playwright/expect-expect': [
        'error',
        {
          assertFunctionNames: ['expectPlausibleInAction']
        }
      ],
      'playwright/no-wait-for-timeout': 'off', // justification: it's necessary for engagement and scroll depth tests
      'playwright/no-conditional-in-test': 'off', // justification: it's necessary for generated tests
      'playwright/no-skipped-test': 'off' // justification: test skips are intentional, usually for flakiness on specific browsers
    }
  },
  prettierEslintInteroperabilityConfig
])
