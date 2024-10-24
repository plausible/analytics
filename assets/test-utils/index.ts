/** @format */

import { render, RenderOptions } from '@testing-library/react'
import { ReactNode } from 'react'

/**
 * Makes the fake document in unit tests aware of some tailwind class definitions.
 * Needed for the matcher option ({ hidden: false }) to function at least partially.
 */
const registerPartialTailwindStyle = () => {
  const tailwindStyle = `.invisible { visibility: hidden; }`

  const style = document.createElement('style')
  style.innerHTML = tailwindStyle
  document.head.appendChild(style)
}

const customRender = (ui: ReactNode, options: RenderOptions) => {
  const output = render(ui, options)
  registerPartialTailwindStyle()
  return output
}

export * from '@testing-library/react'
export { customRender as render }
