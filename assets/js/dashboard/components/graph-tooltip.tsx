import React, { ReactNode, useLayoutEffect, useRef, useState } from 'react'
import {
  Transition,
  TransitionClasses,
  TransitionEvents
} from '@headlessui/react'

export const GraphTooltipWrapper = ({
  x,
  y,
  maxX,
  minWidth,
  children,
  className,
  transition
}: {
  x: number
  y: number
  maxX: number
  minWidth: number
  children: ReactNode
  className?: string
  transition?: TransitionClasses & TransitionEvents
}) => {
  const ref = useRef<HTMLDivElement>(null)

  const xOffset = 12

  const [measuredWidth, setMeasuredWidth] = useState(minWidth)

  const leftIfAlignedToRight = x + xOffset
  const leftIfAlignedToLeft = x - xOffset - measuredWidth
  const leftIfCentered = Math.max(0, x - measuredWidth / 2)

  const canFitRight = leftIfAlignedToRight + measuredWidth <= maxX
  const canFitLeft = leftIfAlignedToLeft >= 0
  const position = canFitRight
    ? 'right'
    : canFitLeft
      ? 'left'
      : 'centered-over-top'

  const tooltipLeft = {
    right: leftIfAlignedToRight,
    left: leftIfAlignedToLeft,
    'centered-over-top': leftIfCentered
  }[position]

  useLayoutEffect(() => {
    if (!ref.current) {
      return
    }
    setMeasuredWidth(ref.current.offsetWidth)
  }, [children, className, minWidth])

  return (
    <Transition as={React.Fragment} appear show {...transition}>
      <div
        ref={ref}
        className={className}
        style={{
          minWidth,
          left: tooltipLeft,
          top: y,
          transform:
            position === 'centered-over-top' ? 'translateY(-100%)' : undefined
        }}
      >
        {children}
      </div>
    </Transition>
  )
}
