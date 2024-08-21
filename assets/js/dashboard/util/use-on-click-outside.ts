/** @format */

import { RefObject, useCallback, useEffect } from 'react'

export function useOnClickOutside({
  ref,
  active,
  handler
}: {
  ref: RefObject<HTMLElement>
  active: boolean
  handler: () => void
}) {
  const onClickOutsideClose = useCallback(
    (e: MouseEvent) => {
      const eventTarget = e.target as Element | null

      if (ref.current && eventTarget && ref.current.contains(eventTarget)) {
        return
      }
      handler()
    },
    [ref, handler]
  )

  useEffect(() => {
    const register = () =>
      document.addEventListener('mousedown', onClickOutsideClose)
    const deregister = () =>
      document.removeEventListener('mousedown', onClickOutsideClose)

    if (active) {
      register()
    } else {
      deregister()
    }

    return deregister
  }, [active, onClickOutsideClose])
}
