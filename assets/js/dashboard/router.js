import React from 'react'
import {
  createRouter,
  createRootRoute,
  Outlet,
  createRoute,
} from '@tanstack/react-router'

import Dashboard from './index'
import SourcesModal from './stats/modals/sources'
import ReferrersDrilldownModal from './stats/modals/referrer-drilldown'
import GoogleKeywordsModal from './stats/modals/google-keywords'
import PagesModal from './stats/modals/pages'
import EntryPagesModal from './stats/modals/entry-pages'
import ExitPagesModal from './stats/modals/exit-pages'
import LocationsModal from './stats/modals/locations-modal'
import PropsModal from './stats/modals/props'
import ConversionsModal from './stats/modals/conversions'
import FilterModal from './stats/modals/filter-modal'
import QueryContextProvider from './query-context'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { parseSearch, stringifySearch } from './util/url'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false
    }
  }
})

function DashboardRoute() {
  return (
    <QueryClientProvider client={queryClient}>
      <QueryContextProvider>
        <Dashboard />
        {/** render any children of the root route below */}
        <Outlet />
      </QueryContextProvider>
    </QueryClientProvider>
  )
}

export const rootRoute = createRootRoute({
  component: DashboardRoute,
  // renders null in the <Outlet /> for unhandleable routes like /${site.domain}/does/not/exist
  notFoundComponent: () => null 
})

export const sourcesRoute = createRoute({
  path: 'sources',
  component: () => <SourcesModal currentView="sources" />,
  getParentRoute: () => rootRoute
})

export const utmMediumsRoute = createRoute({
  path: 'utm_mediums',
  component: () => <SourcesModal currentView="utm_mediums" />,
  getParentRoute: () => rootRoute
})

export const utmSourcesRoute = createRoute({
  path: 'utm_sources',
  component: () => <SourcesModal currentView="utm_sources" />,
  getParentRoute: () => rootRoute
})

export const utmCampaignsRoute = createRoute({
  path: 'utm_campaigns',
  component: () => <SourcesModal currentView="utm_campaigns" />,
  getParentRoute: () => rootRoute
})

export const utmContentsRoute = createRoute({
  path: 'utm_contents',
  component: () => <SourcesModal currentView="utm_contents" />,
  getParentRoute: () => rootRoute
})

export const utmTermsRoute = createRoute({
  path: 'utm_terms',
  component: () => <SourcesModal currentView="utm_terms" />,
  getParentRoute: () => rootRoute
})

export const referrersGoogleRoute = createRoute({
  path: 'referrers/Google',
  component: GoogleKeywordsModal,
  getParentRoute: () => rootRoute
})

export const topPagesRoute = createRoute({
  path: 'pages',
  component: PagesModal,
  getParentRoute: () => rootRoute
})

export const entryPagesRoute = createRoute({
  path: 'entry-pages',
  component: EntryPagesModal,
  getParentRoute: () => rootRoute
})

export const exitPagesRoute = createRoute({
  path: 'exit-pages',
  component: ExitPagesModal,
  getParentRoute: () => rootRoute
})

export const countriesRoute = createRoute({
  path: 'countries',
  component: () => <LocationsModal currentView="countries" />,
  getParentRoute: () => rootRoute
})

export const regionsRoute = createRoute({
  path: 'regions',
  component: () => <LocationsModal currentView="regions" />,
  getParentRoute: () => rootRoute
})

export const citiesRoute = createRoute({
  path: 'cities',
  component: () => <LocationsModal currentView="cities" />,
  getParentRoute: () => rootRoute
})

export const conversionsRoute = createRoute({
  path: 'conversions',
  component: ConversionsModal,
  getParentRoute: () => rootRoute
})

export const referrersDrilldownRoute = createRoute({
  path: 'referrers/$referrer',
  component: ReferrersDrilldownModal,
  getParentRoute: () => rootRoute
})

export const customPropsRoute = createRoute({
  path: 'custom-prop-values/$propKey',
  component: PropsModal,
  getParentRoute: () => rootRoute
})

export const filterRoute = createRoute({
  path: 'filter/$field',
  component: FilterModal,
  getParentRoute: () => rootRoute
})

const routeTree = rootRoute.addChildren([
  sourcesRoute,
  utmMediumsRoute,
  utmSourcesRoute,
  utmCampaignsRoute,
  utmContentsRoute,
  utmTermsRoute,
  referrersGoogleRoute,
  referrersDrilldownRoute,
  topPagesRoute,
  entryPagesRoute,
  exitPagesRoute,
  countriesRoute,
  regionsRoute,
  citiesRoute,
  conversionsRoute,
  customPropsRoute,
  filterRoute
])


export function createAppRouter(site) {
  const basepath = site.shared
    ? `/share/${encodeURIComponent(site.domain)}`
    : encodeURIComponent(site.domain)

  return createRouter({
    routeTree,
    stringifySearch: stringifySearch,
    parseSearch: parseSearch,
    basepath
  })
}
