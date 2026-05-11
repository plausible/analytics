import React, { ReactNode, useLayoutEffect, useRef, useState } from 'react'
import {
  Transition,
  TransitionClasses,
  TransitionEvents
} from '@headlessui/react'

export const GraphTooltipWrapper = ({
  anchor,
  x,
  y,
  maxX,
  minWidth,
  children,
  className,
  transition
}: {
  anchor: 'topEdge' | 'bottomEdge'
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

  const leftByAlignment = {
    alignedRight: x + xOffset,
    alignedLeft: x - xOffset - measuredWidth,
    alignedRightClamped: Math.max(0, Math.min(x, maxX - measuredWidth))
  }

  const canFitRight = leftByAlignment.alignedRight + measuredWidth <= maxX
  const canFitLeft = leftByAlignment.alignedLeft >= 0
  const position = canFitRight
    ? 'alignedRight'
    : canFitLeft
      ? 'alignedLeft'
      : 'alignedRightClamped'

  useLayoutEffect(() => {
    if (!ref.current) {
      return
    }
    setMeasuredWidth(ref.current.offsetWidth)
  }, [children, className, minWidth])

  const extraStyleByAnchor = {
    topEdge: {},
    bottomEdge: { transform: 'translateY(-100%)' }
  }

  return (
    <Transition as={React.Fragment} appear show {...transition}>
      <div
        ref={ref}
        className={className}
        style={{
          minWidth,
          left: leftByAlignment[position],
          top: y,
          ...extraStyleByAnchor[anchor]
        }}
      >
        {children}
      </div>
    </Transition>
  )
}
