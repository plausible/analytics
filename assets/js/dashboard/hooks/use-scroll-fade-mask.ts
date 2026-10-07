import { useCallback, useLayoutEffect, useRef, useState } from 'react'

const SCROLL_FADE_PX = 32

type ScrollOverflow = { start: boolean; end: boolean }

const getScrollOverflow = (element: HTMLElement): ScrollOverflow => ({
  start: element.scrollLeft > 1,
  end: element.scrollLeft + element.clientWidth < element.scrollWidth - 1
})

const getFadeMask = ({ start, end }: ScrollOverflow) => {
  if (!start && !end) {
    return undefined
  }
  const from = start ? `transparent, black ${SCROLL_FADE_PX}px` : 'black'
  const to = end
    ? `black calc(100% - ${SCROLL_FADE_PX}px), transparent`
    : 'black'
  return `linear-gradient(to right, ${from}, ${to})`
}

export function useScrollFadeMask<T extends HTMLElement>() {
  const ref = useRef<T>(null)
  const [overflow, setOverflow] = useState<ScrollOverflow>({
    start: false,
    end: false
  })

  const update = useCallback(() => {
    const element = ref.current
    if (!element) {
      return
    }
    const next = getScrollOverflow(element)
    setOverflow((current) =>
      current.start === next.start && current.end === next.end ? current : next
    )
  }, [])

  useLayoutEffect(() => {
    const element = ref.current
    if (!element) {
      return
    }
    // children can grow without resizing the scroll container itself
    const resizeObserver = new ResizeObserver(update)
    resizeObserver.observe(element)
    Array.from(element.children).forEach((child) =>
      resizeObserver.observe(child)
    )
    element.addEventListener('scroll', update, { passive: true })
    return () => {
      resizeObserver.disconnect()
      element.removeEventListener('scroll', update)
    }
  }, [update])

  return { ref, maskImage: getFadeMask(overflow), update }
}
