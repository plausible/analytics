import React, { ReactNode, RefObject, useLayoutEffect, useState } from 'react'
import {
  Transition,
  TransitionClasses,
  TransitionEvents
} from '@headlessui/react'

type GraphTooltipWrapperProps = {
  verticalAnchor: 'topEdge' | 'bottomEdge'
  horizontalAnchor: 'start' | 'middle'
  x: number
  y: number
  maxX: number
  minWidth: number
  children: ReactNode
  className?: string
  transition?: TransitionClasses & TransitionEvents
  wrapperRef: RefObject<HTMLDivElement>
}

export const GraphTooltipWrapper = ({
  verticalAnchor,
  horizontalAnchor,
  x,
  y,
  maxX,
  minWidth,
  children,
  className,
  transition,
  wrapperRef
}: GraphTooltipWrapperProps) => {
  const minX = 0
  const xOffsetFromStart = 12

  const [measuredWidth, setMeasuredWidth] = useState(minWidth)

  const leftByAlignment = {
    start: {
      alignedRight: x + xOffsetFromStart,
      alignedLeft: x - xOffsetFromStart - measuredWidth,
      alignedRightClamped: Math.max(0, Math.min(x, maxX - measuredWidth))
    },
    middle: {
      alignedRight: x - measuredWidth / 2,
      alignedLeft: x - measuredWidth / 2,
      alignedRightClamped: Math.max(
        minX,
        Math.min(x - measuredWidth / 2, maxX - measuredWidth)
      )
    }
  }[horizontalAnchor]

  const canFitRight = {
    start: leftByAlignment.alignedRight + measuredWidth <= maxX,
    middle: x - measuredWidth / 2 >= minX && x + measuredWidth / 2 <= maxX
  }[horizontalAnchor]

  const canFitLeft = {
    start: leftByAlignment.alignedLeft >= minX,
    middle: false
  }[horizontalAnchor]

  const position = canFitRight
    ? 'alignedRight'
    : canFitLeft
      ? 'alignedLeft'
      : 'alignedRightClamped'

  useLayoutEffect(() => {
    if (!wrapperRef?.current) {
      return
    }
    const el = wrapperRef.current
    const w = el.getBoundingClientRect().width
    setMeasuredWidth(w)
  }, [x, maxX, minWidth, className, children, wrapperRef])

  const extraStyleByVerticalAnchor = {
    topEdge: {},
    bottomEdge: { transform: 'translateY(-100%)' }
  }

  return (
    <Transition as={React.Fragment} appear show {...transition}>
      <div
        ref={wrapperRef}
        className={className}
        style={{
          minWidth,
          left: leftByAlignment[position],
          top: y,
          ...extraStyleByVerticalAnchor[verticalAnchor]
        }}
      >
        {children}
      </div>
    </Transition>
  )
}
