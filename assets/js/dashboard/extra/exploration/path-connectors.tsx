import React, {
  useLayoutEffect,
  useCallback,
  useState,
  ReactNode,
  RefObject
} from 'react'
import { JourneyStep } from './journey'

type ClipRect = {
  y: number
  height: number
}

type SVGData = {
  paths: string[]
  width: number
  height: number
  clipY: number
  clipHeight: number
}

function emptySVGData(): SVGData {
  return {
    paths: [],
    width: 0,
    height: 0,
    clipY: 0,
    clipHeight: 0
  }
}

// x-coordinate of a column element's left or right edge in the coordinate
// space of the scroll container, stable across horizontal scrolling.
function columnEdgeX(
  colEl: Element,
  side: 'left' | 'right',
  containerRect: DOMRect,
  scrollLeft: number
): number {
  const rect = colEl.getBoundingClientRect()
  const edgeX = side === 'right' ? rect.right : rect.left
  return edgeX - containerRect.left + scrollLeft
}

// Vertical midpoint of a step row relative to the top of the container.
function stepRowMidY(stepRowEl: Element, containerRect: DOMRect): number {
  const rect = stepRowEl.getBoundingClientRect()
  return (rect.top + rect.bottom) / 2 - containerRect.top
}

// SVG path for a stepped connector with rounded corners.
function steppedPath(x1: number, y1: number, x2: number, y2: number): string {
  const mx = (x1 + x2) / 2
  const dy = y2 - y1

  if (Math.abs(dy) < 1) {
    return `M ${x1} ${y1} H ${x2}`
  }

  const r = Math.min(10, Math.abs(dy) / 2)

  if (dy > 0) {
    return `M ${x1} ${y1} H ${mx - r} A ${r} ${r} 0 0 1 ${mx} ${y1 + r} V ${y2 - r} A ${r} ${r} 0 0 0 ${mx + r} ${y2} H ${x2}`
  } else {
    return `M ${x1} ${y1} H ${mx - r} A ${r} ${r} 0 0 0 ${mx} ${y1 - r} V ${y2 + r} A ${r} ${r} 0 0 1 ${mx + r} ${y2} H ${x2}`
  }
}

// Clip rect that keeps connectors inside the list area,
// preventing them from bleeding into column headers.
function listClipRect(container: Element, containerRect: DOMRect): ClipRect {
  const firstList = container.querySelector('[data-exploration-list]')
  if (!firstList) return { y: 0, height: container.clientHeight }
  const rect = firstList.getBoundingClientRect()
  return { y: rect.top - containerRect.top, height: rect.height }
}

function computeConnectors(container: Element, steps: JourneyStep[]): SVGData {
  const containerRect = container.getBoundingClientRect()
  const paths = []

  for (let i = 0; i < steps.length - 1; i++) {
    // Query by explicit column index so DOM order never causes a mismatch.
    const colA = container.querySelector(`[data-exploration-column="${i}"]`)
    const colB = container.querySelector(`[data-exploration-column="${i + 1}"]`)
    const rowA = container.querySelector(`[data-exploration-step="${i}"]`)
    const rowB = container.querySelector(`[data-exploration-step="${i + 1}"]`)

    if (colA && colB && rowA && rowB) {
      const x1 = columnEdgeX(colA, 'right', containerRect, container.scrollLeft)
      const x2 = columnEdgeX(colB, 'left', containerRect, container.scrollLeft)
      const y1 = stepRowMidY(rowA, containerRect)
      const y2 = stepRowMidY(rowB, containerRect)
      paths.push(steppedPath(x1, y1, x2, y2))
    }
  }

  const clip = listClipRect(container, containerRect)

  return {
    paths,
    width: container.scrollWidth,
    height: container.clientHeight,
    clipY: clip.y,
    clipHeight: clip.height
  }
}

// layoutKey is bumped whenever the DOM may have changed in a way that is not
// reflected by a steps reference change, e.g. a dashboardState update. It
// is the caller's responsibility to increment it after such changes.
export function PathConnectors({
  steps,
  containerRef,
  layoutKey
}: {
  steps: JourneyStep[]
  containerRef: RefObject<Element>
  layoutKey: number
}): ReactNode | null {
  const [svgData, setSvgData] = useState(emptySVGData)

  const recalculate = useCallback(() => {
    const container = containerRef.current
    if (container) setSvgData(computeConnectors(container, steps))
  }, [steps, containerRef])

  useLayoutEffect(() => {
    const container = containerRef.current

    if (!container || steps.length < 2) {
      setSvgData(emptySVGData)
      return
    }

    setSvgData(computeConnectors(container, steps))

    const observer = new ResizeObserver(recalculate)
    observer.observe(container)
    window.addEventListener('resize', recalculate)

    const lists: Element[] = Array.from(
      container.querySelectorAll('[data-exploration-list]')
    )
    lists.forEach((list) => list.addEventListener('scroll', recalculate))

    return () => {
      observer.disconnect()
      window.removeEventListener('resize', recalculate)
      lists.forEach((list) => list.removeEventListener('scroll', recalculate))
    }
    // layoutKey is intentionally included: it forces this effect to re-run
    // and recalculate geometry after DOM updates that don't change steps.
  }, [steps, containerRef, recalculate, layoutKey])

  if (svgData.paths.length === 0) return null

  return (
    <svg
      className="absolute inset-0 pointer-events-none overflow-visible"
      height={svgData.height}
    >
      <defs>
        <clipPath id="exploration-list-clip">
          <rect
            x="0"
            y={svgData.clipY}
            width={svgData.width}
            height={svgData.clipHeight}
          />
        </clipPath>
      </defs>
      {svgData.paths.map(
        (d: string, i: number): ReactNode => (
          <path
            key={i}
            d={d}
            fill="none"
            clipPath="url(#exploration-list-clip)"
            className="stroke-indigo-500 dark:stroke-indigo-400"
            strokeWidth="1.5"
          />
        )
      )}
    </svg>
  )
}
