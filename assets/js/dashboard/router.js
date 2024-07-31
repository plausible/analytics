/* @format */
import React from 'react'
import { createBrowserRouter, Outlet } from 'react-router-dom'

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

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false
    }
  }
})

function DashboardElement() {
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

export const rootRoute = {
  path: '/',
  element: <DashboardElement />
}

export const sourcesRoute = {
  path: 'sources',
  element: <SourcesModal currentView="sources" />
}

export const utmMediumsRoute = {
  path: 'utm_mediums',
  element: <SourcesModal currentView="utm_mediums" />
}

export const utmSourcesRoute = {
  path: 'utm_sources',
  element: <SourcesModal currentView="utm_sources" />
}

export const utmCampaignsRoute = {
  path: 'utm_campaigns',
  element: <SourcesModal currentView="utm_campaigns" />
}

export const utmContentsRoute = {
  path: 'utm_contents',
  element: <SourcesModal currentView="utm_contents" />
}

export const utmTermsRoute = {
  path: 'utm_terms',
  element: <SourcesModal currentView="utm_terms" />
}

export const referrersGoogleRoute = {
  path: 'referrers/Google',
  element: <GoogleKeywordsModal />
}

export const topPagesRoute = {
  path: 'pages',
  element: <PagesModal />
}

export const entryPagesRoute = {
  path: 'entry-pages',
  element: <EntryPagesModal />
}

export const exitPagesRoute = {
  path: 'exit-pages',
  element: <ExitPagesModal />
}

export const countriesRoute = {
  path: 'countries',
  element: <LocationsModal currentView="countries" />
}

export const regionsRoute = {
  path: 'regions',
  element: <LocationsModal currentView="regions" />
}

export const citiesRoute = {
  path: 'cities',
  element: <LocationsModal currentView="cities" />
}

export const conversionsRoute = {
  path: 'conversions',
  element: <ConversionsModal />
}

export const referrersDrilldownRoute = {
  path: 'referrers/:referrer',
  element: <ReferrersDrilldownModal />
}

export const customPropsRoute = {
  path: 'custom-prop-values/:propKey',
  element: <PropsModal />
}

export const filterRoute = {
  path: 'filter/:field',
  element: <FilterModal />
}

export function createAppRouter(site) {
  const basepath = site.shared
    ? `/share/${encodeURIComponent(site.domain)}`
    : `/${encodeURIComponent(site.domain)}`

  const router = createBrowserRouter(
    [
      {
        ...rootRoute,
        children: [
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
          filterRoute,
          { path: '*', element: null }
        ]
      }
    ],
    {
      basename: basepath,
      future: {
        v7_prependBasename: true
      }
    }
  )

  return router
}
