import React, { createContext, useContext, useEffect } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { get } from './api'
import { useSiteContext } from './site-context'
import { useDashboardStateContext } from './dashboard-state-context'
import { CACHE_TTL_REALTIME } from './hooks/api-client'
import { isRealTimeDashboard } from './util/filters'

const CurrentVisitorsContext = createContext<number | null>(null)

export function CurrentVisitorsProvider({
  children
}: {
  children: React.ReactNode
}) {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const queryClient = useQueryClient()

  const isEnabled =
    isRealTimeDashboard(dashboardState) || dashboardState.filters.length === 0

  const { data } = useQuery<number>({
    queryKey: ['current-visitors'],
    queryFn: () =>
      get(`/api/stats/${encodeURIComponent(site.domain)}/current-visitors`),
    staleTime: CACHE_TTL_REALTIME,
    enabled: isEnabled
  })

  useEffect(() => {
    const onTick = () => {
      queryClient.invalidateQueries({ queryKey: ['current-visitors'] })
    }
    document.addEventListener('tick', onTick)
    return () => document.removeEventListener('tick', onTick)
  }, [queryClient])

  return (
    <CurrentVisitorsContext.Provider value={isEnabled ? (data ?? null) : null}>
      {children}
    </CurrentVisitorsContext.Provider>
  )
}

export const useCurrentVisitorsContext = () =>
  useContext(CurrentVisitorsContext)
