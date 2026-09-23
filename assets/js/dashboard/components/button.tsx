import React from 'react'
import classNames from 'classnames'

/**
 * Themes and sizes are kept in sync with the Phoenix `button` component in
 * `lib/plausible_web/components/generic.ex`. The actual Tailwind classes live
 * in `assets/css/app.css` (.btn-base, .btn-{xs,sm,md}, .btn-theme-*).
 */

export type ButtonTheme =
  | 'primary'
  | 'secondary'
  | 'danger'
  | 'yellow'
  | 'ghost'
  | 'link'

export type ButtonSize = 'xs' | 'sm' | 'md'

const buttonBaseClass = 'btn-base'

const buttonIconClass = 'btn-icon'

const buttonSizes: Record<ButtonSize, string> = {
  xs: 'btn-xs',
  sm: 'btn-sm',
  md: 'btn-md'
}

const buttonThemes: Record<ButtonTheme, string> = {
  primary: 'btn-theme-primary',
  secondary: 'btn-theme-secondary',
  yellow: 'btn-theme-yellow',
  danger: 'btn-theme-danger',
  ghost: 'btn-theme-ghost',
  link: 'btn-theme-link'
}

export const buttonClassName = ({
  theme = 'primary',
  size = 'md',
  icon = false,
  className
}: {
  theme?: ButtonTheme
  size?: ButtonSize
  icon?: boolean
  className?: string
} = {}): string =>
  classNames(
    buttonBaseClass,
    buttonSizes[size],
    buttonThemes[theme],
    icon && buttonIconClass,
    className
  )

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  theme?: ButtonTheme
  size?: ButtonSize
  icon?: boolean
}

export const Button = ({
  theme = 'primary',
  size = 'md',
  icon = false,
  type = 'button',
  className,
  ...rest
}: ButtonProps) => (
  <button
    type={type}
    className={buttonClassName({ theme, size, icon, className })}
    {...rest}
  />
)
