import React from 'react'
import { tooltipClassName } from '../../util/tooltip'

interface MapTooltipProps {
  name: string
  value: string
  label: string
  x: number
  y: number
}

export const MapTooltip = ({ name, value, label, x, y }: MapTooltipProps) => (
  <div
    className={tooltipClassName({
      size: 'sm',
      theme: 'darker',
      className: 'absolute z-50 translate-x-2 translate-y-2 pointer-events-none'
    })}
    style={{
      left: x,
      top: y
    }}
  >
    <div className="font-semibold">{name}</div>
    <div className="flex items-center gap-x-1">
      <span className="font-semibold">{value}</span>
      <span className="font-normal">{label}</span>
    </div>
  </div>
)
