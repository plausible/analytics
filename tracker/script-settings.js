import { DEFAULT_GLOBALS } from './compiler/index.js'

export const DEFAULT_BOOLEAN_SETTINGS = Object.fromEntries(
  Object.entries(DEFAULT_GLOBALS).map(([global]) => [global, 'readonly'])
)

export const NON_BOOLEAN_SCRIPT_GLOBALS = {
  plausible: false
}
