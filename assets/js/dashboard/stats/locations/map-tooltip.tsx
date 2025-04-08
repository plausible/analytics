import classNames from 'classnames'
import React from 'react'

interface MapTooltipProps {
  name: string
  value: string
  label: string
  x: number
  y: number
}

export const MapTooltip = ({ name, value, label, x, y }: MapTooltipProps) => (
  <div
    className={classNames(
      'absolute',
      'z-50',
      'p-2',
      'translate-x-2',
      'translate-y-2',
      'pointer-events-none',
      'rounded-sm',
      'bg-white',
      'dark:bg-gray-800',
      'shadow',
      'dark:border-gray-850',
      'dark:text-gray-200',
      'dark:shadow-gray-850',
      'shadow-gray-200'
    )}
    style={{
      left: x,
      top: y
    }}
  >
    <div className="font-semibold">{name}</div>
    <strong className="dark:text-indigo-400">{value}</strong> {label}
  </div>
)
