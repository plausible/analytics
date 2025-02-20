/** @format */

import React, { ReactNode } from 'react'
import SiteContextProvider, {
  PlausibleSite
} from '../js/dashboard/site-context'
import UserContextProvider, { Role } from '../js/dashboard/user-context'
import { MemoryRouter, MemoryRouterProps } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import QueryContextProvider from '../js/dashboard/query-context'
import { getRouterBasepath } from '../js/dashboard/router'
import { RoutelessModalsContextProvider } from '../js/dashboard/navigation/routeless-modals-context'

type TestContextProvidersProps = {
  children: ReactNode
  routerProps?: Pick<MemoryRouterProps, 'initialEntries'>
  siteOptions?: Partial<PlausibleSite>
}

export const TestContextProviders = ({
  children,
  routerProps,
  siteOptions
}: TestContextProvidersProps) => {
  const defaultSite: PlausibleSite = {
    domain: 'plausible.io/unit',
    offset: 0,
    hasGoals: false,
    hasProps: false,
    scrollDepthVisible: false,
    funnelsAvailable: false,
    propsAvailable: false,
    siteSegmentsAvailable: false,
    conversionsOptedOut: false,
    funnelsOptedOut: false,
    propsOptedOut: false,
    revenueGoals: [],
    funnels: [],
    statsBegin: '',
    nativeStatsBegin: '',
    embedded: false,
    background: '',
    isDbip: false,
    flags: {},
    validIntervalsByPeriod: {},
    shared: false,
    members: { 1: 'Test User' }
  }

  const site = { ...defaultSite, ...siteOptions }

  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        refetchOnWindowFocus: false
      }
    }
  })

  const defaultInitialEntries = [getRouterBasepath(site)]

  return (
    // <ThemeContextProvider> not interactive component, default value is suitable
    <SiteContextProvider site={site}>
      <UserContextProvider user={{ role: Role.admin, loggedIn: true, id: 1 }}>
        <MemoryRouter
          basename={getRouterBasepath(site)}
          initialEntries={defaultInitialEntries}
          {...routerProps}
        >
          <QueryClientProvider client={queryClient}>
            <RoutelessModalsContextProvider>
              <QueryContextProvider>{children}</QueryContextProvider>
            </RoutelessModalsContextProvider>
          </QueryClientProvider>
        </MemoryRouter>
      </UserContextProvider>
    </SiteContextProvider>
    // </ThemeContextProvider>
  )
}
