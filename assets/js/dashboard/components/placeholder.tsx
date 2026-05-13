import classNames from 'classnames'
import React, { ReactNode } from 'react'

export const Placeholder = ({
  children,
  placeholder
}: {
  children: ReactNode | false
  placeholder: ReactNode
}) => (
  <span
    className={classNames(
      'rounded',
      children === false &&
        'bg-gray-100 dark:bg-gray-700 text-gray-100 dark:text-gray-700'
    )}
  >
    {children === false ? placeholder : children}
  </span>
)
