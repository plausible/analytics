import React from 'react'
import classNames from 'classnames'

/**
 * Themes and sizes are kept in sync with the Phoenix `button` component in
 * `lib/plausible_web/components/generic.ex`. The actual Tailwind classes live
 * in `assets/css/app.css` (.btn-base, .btn-{sm,md}, .btn-theme-*).
 */

export type ButtonTheme =
  | 'primary'
  | 'secondary'
  | 'danger'
  | 'yellow'
  | 'ghost'
  | 'icon'

export type ButtonSize = 'sm' | 'md'

const buttonBaseClass = 'btn-base'

const buttonSizes: Record<ButtonSize, string> = {
  sm: 'btn-sm',
  md: 'btn-md'
}

const buttonThemes: Record<ButtonTheme, string> = {
  primary: 'btn-theme-primary',
  secondary: 'btn-theme-secondary',
  yellow: 'btn-theme-yellow',
  danger: 'btn-theme-danger',
  ghost: 'btn-theme-ghost',
  icon: 'btn-theme-icon'
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
