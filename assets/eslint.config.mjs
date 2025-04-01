import { defineConfig } from 'eslint/config'
import globals from 'globals'
import pluginJs from '@eslint/js'
import { configs as pluginTypescriptEslintConfigs } from 'typescript-eslint'
import pluginReact from 'eslint-plugin-react'
import pluginReactHooks from 'eslint-plugin-react-hooks'
import pluginA11y from 'eslint-plugin-jsx-a11y'
import pluginImport from 'eslint-plugin-import'
import pluginJest from 'eslint-plugin-jest'
import prettierEslintInteroperabilityConfig from 'eslint-config-prettier/flat'

export default defineConfig([
  {
    files: ['**/*.{js,ts,jsx,tsx}'],
    languageOptions: { globals: globals.browser }
  },
  {
    files: ['**/*.{js,ts,jsx,tsx}'],
    plugins: { js: pluginJs },
    extends: ['js/recommended']
  },
  {
    rules: {
      'no-prototype-builtins': ['off'],
      'no-unused-expressions': ['warn', { allowShortCircuit: true }]
    }
  },

  {
    files: ['**/*.test.{js,ts,jsx,tsx}'],
    plugins: { jest: pluginJest },
    languageOptions: {
      globals: pluginJest.environments.globals.globals
    },
    rules: {
      'jest/no-disabled-tests': 'warn',
      'jest/no-focused-tests': 'error',
      'jest/no-identical-title': 'error',
      'jest/prefer-to-have-length': 'warn',
      'jest/valid-expect': 'error'
    }
  },

  pluginTypescriptEslintConfigs.recommended,
  {
    rules: {
      '@typescript-eslint/no-unused-vars': [
        'error',
        {
          args: 'all',
          argsIgnorePattern: '^_',
          caughtErrors: 'all',
          caughtErrorsIgnorePattern: '^_',
          destructuredArrayIgnorePattern: '^_',
          varsIgnorePattern: '^_',
          ignoreRestSiblings: true
        }
      ]
    }
  },

  pluginImport.flatConfigs.recommended,
  pluginImport.flatConfigs.typescript,
  {
    settings: {
      'import/resolver': { typescript: true, node: { paths: ['../deps'] } }
    }
  },

  pluginReact.configs.flat.recommended,
  {
    settings: {
      react: {
        version: 'detect'
      }
    },
    rules: {
      'react/destructuring-assignment': ['off'],
      'react/self-closing-comp': ['off'],
      'react/jsx-props-no-spreading': ['off'],
      'react/jsx-one-expression-per-line': ['off'],
      'react/display-name': ['off'],
      'react/prop-types': ['off'],
      'react/no-unknown-property': ['error', { ignore: ['tooltip'] }],
      'react/no-did-update-set-state': ['off']
    }
  },
  pluginReactHooks.configs['recommended-latest'],

  pluginA11y.flatConfigs.recommended,
  {
    rules: {
      'jsx-a11y/click-events-have-key-events': ['off'],
      'jsx-a11y/no-static-element-interactions': ['off']
    }
  },

  prettierEslintInteroperabilityConfig
])
