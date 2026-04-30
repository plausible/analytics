import React from 'react'
import classNames from 'classnames'

/**
 * Themes and sizes are kept in sync with the Phoenix `button` component in
 * `lib/plausible_web/components/generic.ex`. Update both together.
 */

export type ButtonTheme =
  | 'primary'
  | 'secondary'
  | 'danger'
  | 'yellow'
  | 'ghost'
  | 'icon'

export type ButtonSize = 'sm' | 'md'

const buttonBaseClass =
  'whitespace-nowrap truncate inline-flex items-center justify-center gap-x-2 text-sm font-medium rounded-md cursor-pointer disabled:cursor-not-allowed'

const buttonSizes: Record<ButtonSize, string> = {
  sm: 'px-3 py-2',
  md: 'px-3.5 py-2.5'
}

const buttonThemes: Record<ButtonTheme, string> = {
  primary:
    'border border-indigo-600 bg-indigo-600 text-white hover:bg-indigo-700 focus-visible:outline-indigo-600 disabled:border-transparent disabled:bg-indigo-400/60 disabled:dark:bg-indigo-600/30 disabled:dark:text-white/35',
  secondary:
    'border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-700 text-gray-800 dark:text-gray-100 hover:bg-gray-50 hover:text-gray-900 dark:hover:bg-gray-600 dark:hover:border-gray-600 dark:hover:text-white disabled:text-gray-700/40 dark:disabled:text-gray-500 dark:disabled:bg-gray-800 dark:disabled:border-gray-800',
  yellow:
    'border border-yellow-600/90 bg-yellow-600/90 text-white hover:bg-yellow-600 focus-visible:outline-yellow-600 disabled:border-yellow-400/60 disabled:bg-yellow-400/60 disabled:dark:border-yellow-600/30 disabled:dark:bg-yellow-600/30 disabled:dark:text-white/35',
  danger:
    'border border-gray-300 dark:border-gray-800 text-red-600 bg-white dark:bg-gray-800 hover:text-red-700 dark:hover:text-red-400 dark:text-red-500 active:text-red-800 disabled:text-red-700/40 disabled:hover:shadow-none dark:disabled:text-red-500/35 dark:disabled:bg-gray-800',
  ghost:
    'border border-transparent text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-gray-100 hover:bg-gray-100 dark:hover:bg-gray-800 hover:border-gray-100 dark:hover:border-gray-800 disabled:text-gray-500 disabled:dark:text-gray-600 disabled:hover:bg-transparent disabled:hover:border-transparent',
  icon: 'border border-transparent text-gray-400 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-100'
}

export const buttonClassName = ({
  theme = 'primary',
  size = 'md',
  className
}: {
  theme?: ButtonTheme
  size?: ButtonSize
  className?: string
} = {}): string =>
  classNames(buttonBaseClass, buttonSizes[size], buttonThemes[theme], className)

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  theme?: ButtonTheme
  size?: ButtonSize
}

export const Button = ({
  theme = 'primary',
  size = 'md',
  type = 'button',
  className,
  ...rest
}: ButtonProps) => (
  <button
    type={type}
    className={buttonClassName({ theme, size, className })}
    {...rest}
  />
)
