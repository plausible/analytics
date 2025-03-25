import { useEffect, useRef, useCallback } from 'react'

// A custom hook that behaves like `useEffect`, but
// the function does not run on the initial render.
export function useMountedEffect(fn, deps) {
  const mounted = useRef(false)

  useEffect(() => {
    if (mounted.current) {
      fn()
    } else {
      mounted.current = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps)
}

const DEBOUNCE_DELAY = 300

export function useDebounce(fn, delay = DEBOUNCE_DELAY) {
  const timerRef = useRef(null)

  useEffect(() => {
    return () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current)
      }
    }
  }, [])

  return useCallback(
    (...args) => {
      clearTimeout(timerRef.current)

      timerRef.current = setTimeout(() => {
        fn(...args)
      }, delay)
    },
    [fn, delay]
  )
}
