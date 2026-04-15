import React, { ReactNode, useLayoutEffect, useRef, useState } from 'react'
import { Transition } from '@headlessui/react'

export const GraphTooltipWrapper = ({
  x,
  y,
  maxX,
  minWidth,
  children,
  className,
  onClick,
  isTouchDevice
}: {
  x: number
  y: number
  maxX: number
  minWidth: number
  children: ReactNode
  className?: string
  onClick?: () => void
  isTouchDevice?: boolean
}) => {
  const ref = useRef<HTMLDivElement>(null)
  // bigger on mobile to have room between thumb and tooltip
  const xOffsetFromCursor = isTouchDevice ? 24 : 12
  const yOffsetFromCursor = isTouchDevice ? 48 : 24
  const [measuredWidth, setMeasuredWidth] = useState(minWidth)
  // center tooltip above the cursor, clamped to prevent left/right overflow
  const rawLeft = x + xOffsetFromCursor
  const tooltipLeft = Math.max(0, Math.min(rawLeft, maxX - measuredWidth))

  useLayoutEffect(() => {
    if (!ref.current) {
      return
    }
    setMeasuredWidth(ref.current.offsetWidth)
  }, [children, className, minWidth])

  return (
    <Transition
      as={React.Fragment}
      appear
      show
      // enter delay on mobile is needed to prevent the tooltip from entering when the user starts to y-pan
      // but the y-pan is not yet certain
      enter={isTouchDevice ? 'transition-opacity duration-0 delay-150' : ''}
      enterFrom={isTouchDevice ? 'opacity-0' : ''}
      enterTo={isTouchDevice ? 'opacity-100' : ''}
    >
      <div
        ref={ref}
        className={className}
        onClick={onClick}
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
