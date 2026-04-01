import React, { ReactNode, useLayoutEffect, useRef, useState } from 'react'

export const GraphTooltipWrapper = ({
  x,
  y,
  maxX,
  minWidth,
  bucketIndex,
  totalBuckets,
  children,
  className,
  onClick
}: {
  x: number
  y: number
  maxX: number
  minWidth: number
  bucketIndex: number
  totalBuckets: number
  children: ReactNode
  className?: string
  onClick?: () => void
}) => {
  const ref = useRef<HTMLDivElement>(null)
  // distance from cursor to tooltip edge
  const offsetFromCursor = 4
  // flip the tooltip to left of cursor if it would overflow on the right
  // and keep it flipped to the left for all subsequent buckets
  // even if they'd fit on the right (prevents excessive flips)
  const [firstFlippedToLeftOn, setFirstFlippedToLeftOn] = useState<
    number | null
  >(null)
  const [measuredWidth, setMeasuredWidth] = useState(minWidth)
  const position =
    firstFlippedToLeftOn !== null && bucketIndex >= firstFlippedToLeftOn
      ? 'leftOfCursor'
      : 'rightOfCursor'
  const rawLeft =
    position === 'leftOfCursor'
      ? x - offsetFromCursor - measuredWidth
      : x + offsetFromCursor
  // prevent tooltip from oveflowing on the left when flipped to left of cursor on smaller screens
  const tooltipLeft = Math.max(0, Math.min(rawLeft, maxX - measuredWidth))

  useLayoutEffect(() => {
    setFirstFlippedToLeftOn(null)
  }, [totalBuckets])

  useLayoutEffect(() => {
    if (!ref.current) {
      return
    }
    const w = ref.current.offsetWidth
    setMeasuredWidth(w)
    const wouldOverflow = x + offsetFromCursor + w > maxX
    setFirstFlippedToLeftOn((prev) => {
      if (wouldOverflow) {
        return prev === null ? bucketIndex : Math.min(prev, bucketIndex)
      }
      if (prev !== null && bucketIndex < prev) {
        return null
      }
      return prev
    })
  }, [x, maxX, bucketIndex])

  return (
    <div
      ref={ref}
      className={className}
      onClick={onClick}
      style={{
        minWidth,
        left: tooltipLeft,
        top: y,
        transform: `translateY(-100%) translateY(-${offsetFromCursor}px)`
      }}
    >
      {children}
    </div>
  )
}
