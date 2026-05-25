import React, { ReactNode } from 'react'
import classNames from 'classnames'

export type PillColor = 'green' | 'yellow'

const colorClasses: Record<PillColor, string> = {
  green: 'bg-green-50 dark:bg-green-900/60 text-green-700 dark:text-green-300',
  yellow:
    'bg-yellow-100 dark:bg-yellow-900/40 text-yellow-600 dark:text-yellow-400'
}

export type PillProps = {
  className?: string
  color?: PillColor
  children: ReactNode
}

export function Pill({ className, color = 'green', children }: PillProps) {
  return (
    <div
      className={classNames(
        'flex items-center gap-x-1 shrink-0 h-fit rounded-md text-xs font-medium px-2.5 py-1',
        colorClasses[color],
        className
      )}
    >
      {children}
    </div>
  )
}
