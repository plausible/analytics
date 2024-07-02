import { useEffect, useRef } from 'react';

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