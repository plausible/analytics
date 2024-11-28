/** @format */
import React from 'react'
import { createBrowserRouter, Outlet, useRouteError } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

import { PlausibleSite, useSiteContext } from './site-context'
import {
  GoBackToDashboard,
  SomethingWentWrongMessage
} from './error/something-went-wrong'
import Dashboard from './index'
import SourcesModal from './stats/modals/sources'
import ReferrersDrilldownModal from './stats/modals/referrer-drilldown'
import GoogleKeywordsModal from './stats/modals/google-keywords'
import PagesModal from './stats/modals/pages'
import EntryPagesModal from './stats/modals/entry-pages'
import ExitPagesModal from './stats/modals/exit-pages'
import LocationsModal from './stats/modals/locations-modal'
import BrowsersModal from './stats/modals/devices/browsers-modal'
import BrowserVersionsModal from './stats/modals/devices/browser-versions-modal'
import OperatingSystemsModal from './stats/modals/devices/operating-systems-modal'
import OperatingSystemVersionsModal from './stats/modals/devices/operating-system-versions-modal'
import ScreenSizesModal from './stats/modals/devices/screen-sizes'
import PropsModal from './stats/modals/props'
import ConversionsModal from './stats/modals/conversions'
import FilterModal from './stats/modals/filter-modal'
import QueryContextProvider from './query-context'
import { DashboardKeybinds } from './dashboard-keybinds'
import LastLoadContextProvider from './last-load-context'

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
        <LastLoadContextProvider>
          <Dashboard />
          {/** render any children of the root route below */}
        </LastLoadContextProvider>
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

export const channelsRoute = {
  path: 'channels',
  element: <SourcesModal currentView="channels" />
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

export const browsersRoute = {
  path: 'browsers',
  element: <BrowsersModal />
}

export const browserVersionsRoute = {
  path: 'browser-versions',
  element: <BrowserVersionsModal />
}

export const operatingSystemsRoute = {
  path: 'operating-systems',
  element: <OperatingSystemsModal />
}

export const operatingSystemVersionsRoute = {
  path: 'operating-system-versions',
  element: <OperatingSystemVersionsModal />
}

export const screenSizesRoute = {
  path: 'screen-sizes',
  element: <ScreenSizesModal />
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

export const editSegmentRoute = {
  path: 'filter/segment/:id/*',
  element: <></>
}

export const filterRoute = {
  path: 'filter/:field',
  element: <FilterModal />
}

export const editSegmentFilterRoute = {
  path: `filter/segment/:id/${filterRoute.path}`,
  element: <FilterModal />
}

export function getRouterBasepath(
  site: Pick<PlausibleSite, 'shared' | 'domain'>
): string {
  const basepath = site.shared
    ? `/share/${encodeURIComponent(site.domain)}`
    : `/${encodeURIComponent(site.domain)}`
  return basepath
}

function RouteErrorElement() {
  const site = useSiteContext()
  const error = useRouteError()
  return (
    <SomethingWentWrongMessage
      error={error}
      callToAction={<GoBackToDashboard site={site} />}
    />
  )
}

export function createAppRouter(site: PlausibleSite) {
  const basepath = getRouterBasepath(site)
  const router = createBrowserRouter(
    [
      {
        ...rootRoute,
        errorElement: <RouteErrorElement />,
        children: [
          { index: true, element: <DashboardKeybinds /> },
          sourcesRoute,
          channelsRoute,
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
          browsersRoute,
          browserVersionsRoute,
          operatingSystemsRoute,
          operatingSystemVersionsRoute,
          screenSizesRoute,
          conversionsRoute,
          customPropsRoute,
          filterRoute,
          editSegmentRoute,
          editSegmentFilterRoute,
          { path: '*', element: null }
        ]
      }
    ],
    {
      basename: basepath,
      future: {
        // @ts-expect-error valid according to docs (https://reactrouter.com/en/main/routers/create-browser-router#optsfuture)
        v7_prependBasename: true
      }
    }
  )

  return router
}
