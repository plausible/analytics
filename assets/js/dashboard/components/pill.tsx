import React, { ReactNode } from 'react'
import classNames from 'classnames'

export type PillProps = {
  className?: string
  children: ReactNode
}

export function Pill({ className, children }: PillProps) {
  return (
    <div
      className={classNames(
        'flex items-center shrink-0 h-fit rounded-md bg-green-50 dark:bg-green-900/60 text-green-700 dark:text-green-300 text-xs font-medium px-2.5 py-1',
        className
      )}
    >
      {children}
    </div>
  )
}
