import { useEffect, useMemo, useState } from 'react'
import { useLocation } from 'react-router-dom'
import { useAppNavigate } from './use-app-navigate'

/**
 * This hook should be rendered once in the app, since it hooks into each navigation
 * (re-navigating with replace: true on most navigations). It does so to
 * replace undefined `location.state[key]` with a known definite value.
 * The way to unset `location.state[key]` is to set it to null in navigation.
 * This is to make sure that normal navigations (open Details etc) don't need to declare
 * that they want to keep previous location.state.
 */
export function useDefiniteLocationState<T>(key: string): {
  definiteValue: T | null
} {
  const location = useLocation()
  const rawState = useMemo(() => location.state ?? {}, [location.state])

  const navigate = useAppNavigate()

  const [definiteValue, setDefiniteValue] = useState<T | null>(
    rawState[key] === undefined ? null : (rawState[key] as T)
  )

  useEffect(() => {
    if (rawState[key] === undefined) {
      navigate({
        search: (s) => s,
        state: { ...rawState, [key]: definiteValue },
        replace: true
      })
    }
  }, [definiteValue, rawState, navigate, key])

  useEffect(() => {
    if (rawState[key] !== undefined && rawState[key] !== definiteValue) {
      setDefiniteValue(rawState[key] as T)
    }
  }, [rawState, definiteValue, key])

  return { definiteValue }
}
