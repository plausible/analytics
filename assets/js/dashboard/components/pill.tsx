import React, { ReactNode } from 'react'
import classNames from 'classnames'
import { DiamondIcon } from './icons'

export type PillColor = 'green' | 'yellow' | 'indigo'

const colorClasses: Record<PillColor, string> = {
  green: 'bg-green-50 dark:bg-green-900/60 text-green-700 dark:text-green-300',
  yellow:
    'bg-yellow-100 dark:bg-yellow-900/40 text-yellow-600 dark:text-yellow-400',
  indigo:
    'bg-indigo-100/60 text-indigo-600 dark:bg-indigo-900/50 dark:text-indigo-300'
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
        'flex items-center gap-x-1 shrink-0 h-fit rounded-md text-xs font-medium px-2 py-1',
        colorClasses[color],
        className
      )}
    >
      {children}
    </div>
  )
}

export function UpgradePill({
  plan,
  color = 'indigo',
  linked = false
}: {
  plan: string
  color?: PillColor
  linked?: boolean
}) {
  const pill = (
    <Pill color={color}>
      <DiamondIcon className="size-3.5 [&_path]:stroke-2" />
      {plan}
    </Pill>
  )
  if (!linked) {
    return pill
  }
  return (
    <a href="/billing/choose-plan" className="inline-block">
      {pill}
    </a>
  )
}
