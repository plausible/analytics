import { useEffect, useRef, useCallback } from 'react';

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
  }, deps)
}

const DEBOUNCE_DELAY = 300

export function useDebounce(fn, delay = DEBOUNCE_DELAY) {
  const timerRef = useRef(null)

  return useCallback((...args) => {
    clearTimeout(timerRef.current)

    timerRef.current = setTimeout(() => {
      fn(...args)
    }, delay)
  }, [fn, delay])
}