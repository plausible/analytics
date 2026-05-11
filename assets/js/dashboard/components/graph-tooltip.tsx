import React, {
  ReactNode,
  RefObject,
  useLayoutEffect,
  useState
} from 'react'
import {
  Transition,
  TransitionClasses,
  TransitionEvents
} from '@headlessui/react'

type GraphTooltipWrapperProps = {
  anchor: 'topEdge' | 'bottomEdge'
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
  anchor,
  x,
  y,
  maxX,
  minWidth,
  children,
  className,
  transition,
  wrapperRef
}: GraphTooltipWrapperProps) => {
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
    if (!wrapperRef?.current) {
      return
    }
    const el = wrapperRef.current
    const w = el.getBoundingClientRect().width
    setMeasuredWidth(w)
  }, [x, maxX, minWidth, className, children, wrapperRef])

  const extraStyleByAnchor = {
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
          ...extraStyleByAnchor[anchor]
        }}
      >
        {children}
      </div>
    </Transition>
  )
}
