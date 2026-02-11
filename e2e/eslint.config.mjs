import eslint from '@eslint/js'
import pluginPlaywright from 'eslint-plugin-playwright'
import prettierEslintInteroperabilityConfig from 'eslint-config-prettier/flat'
import tseslint from 'typescript-eslint'

export default tseslint.config([
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
  // config for tests of tracker scripts and installation support scripts
  {
    files: ['tests/**/*.ts'],
    ...pluginPlaywright.configs['flat/recommended'],
    languageOptions: {
      ecmaVersion: 'latest'
    },
    rules: {
      ...pluginPlaywright.configs['flat/recommended'].rules,
      'playwright/expect-expect': [
        'error',
        {
          assertFunctionNames: ['expectLiveViewConnected']
        }
      ]
    }
  },
  prettierEslintInteroperabilityConfig
])
