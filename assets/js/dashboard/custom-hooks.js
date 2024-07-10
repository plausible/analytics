import { useCallback, useEffect, useRef } from 'react';

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

// A custom hook that debounces the function calls by a given delay.
// The first function call is not delayed. Every subsequent call is
// delayed by `delay_ms`, and if another function is called before
// the delay timeout, the previous function call gets cancelled.
export function useDebouncedEffect(fn, deps, delay_ms) {
  const callback = useCallback(fn, deps)
  const delay = useRef(0)

  useEffect(() => {
    const timeout = setTimeout(() => {
      delay.current = delay_ms
      callback()
    }, delay.current)

    return () => clearTimeout(timeout)
  }, [callback, delay_ms])
}