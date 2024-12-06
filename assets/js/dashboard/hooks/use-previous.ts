import { useRef, useEffect } from 'react';

function usePrevious<T>(value: T): T | undefined {
  const ref = useRef<T | undefined>(undefined);

  useEffect(() => {
    // Update the ref with the current value after render
    ref.current = value;
  }, [value]);

  // Return the previous value
  return ref.current;
}

export default usePrevious;
