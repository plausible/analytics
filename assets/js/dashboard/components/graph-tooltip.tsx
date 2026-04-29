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

  const canFitRight = leftIfAlignedToRight + measuredWidth <= maxX
  const canFitLeft = leftIfAlignedToLeft >= 0
  
  const tooltipLeft = canFitRight
    ? leftIfAlignedToRight
    : canFitLeft
      ? leftIfAlignedToLeft
      : Math.max(0, Math.min(leftIfAlignedToRight, maxX - measuredWidth))

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
        }}
      >
        {children}
      </div>
    </Transition>
  )
}
