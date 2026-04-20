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
  const xOffsetFromCursor = 12
  const yOffsetFromCursor = 24
  const [measuredWidth, setMeasuredWidth] = useState(minWidth)
  // clamp to prevent left/right overflow
  const rawLeft = x + xOffsetFromCursor
  const tooltipLeft = Math.max(0, Math.min(rawLeft, maxX - measuredWidth))

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
          transform: `translateY(-100%) translateY(-${yOffsetFromCursor}px)`
        }}
      >
        {children}
      </div>
    </Transition>
  )
}
