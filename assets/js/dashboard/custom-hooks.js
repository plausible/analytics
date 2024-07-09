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

// A custom hook that debounces the function calls by
// a given delay. Cancels all function calls that have
// a following call within `delay_ms`.
export function useDebouncedEffect(fn, deps, delay_ms) {
  const callback = useCallback(fn, deps)

  useEffect(() => {
    const timeout = setTimeout(callback, delay_ms)
    return () => clearTimeout(timeout)
  }, [callback, delay_ms])
}