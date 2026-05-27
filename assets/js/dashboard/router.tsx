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
import { PagesDetails } from './stats/pages/details'
import { DevicesDetails } from './stats/devices/details'
import {
  BREAKDOWN_REPORTS,
  BreakdownReportKey
} from './stats/reports/reports-config'
import LocationsModal from './stats/modals/locations-modal'
import PropsModal from './stats/modals/props'
import ConversionsModal from './stats/modals/conversions'
import FilterModal from './stats/modals/filter-modal'
import DashboardStateContextProvider from './dashboard-state-context'
import { DashboardKeybinds } from './dashboard-keybinds'
import LastLoadContextProvider from './last-load-context'
import { RoutelessModalsContextProvider } from './navigation/routeless-modals-context'
import { RoutelessSegmentModals } from './segments/routeless-segment-modals'

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
      <RoutelessModalsContextProvider>
        <DashboardStateContextProvider>
          <LastLoadContextProvider>
            <Dashboard />
            {/** render any children of the root route below */}
          </LastLoadContextProvider>
          <Outlet />
          <RoutelessSegmentModals />
        </DashboardStateContextProvider>
      </RoutelessModalsContextProvider>
    </QueryClientProvider>
  )
}

export const rootRoute = {
  path: '/',
  element: <DashboardElement />
}

export const sourcesRoute = {
  path: BREAKDOWN_REPORTS.sources.detailsPath,
  element: <SourcesModal currentView="sources" />
}

export const channelsRoute = {
  path: BREAKDOWN_REPORTS.channels.detailsPath,
  element: <SourcesModal currentView="channels" />
}

export const utmMediumsRoute = {
  path: BREAKDOWN_REPORTS.utmMediums.detailsPath,
  element: <SourcesModal currentView="utm_mediums" />
}

export const utmSourcesRoute = {
  path: BREAKDOWN_REPORTS.utmSources.detailsPath,
  element: <SourcesModal currentView="utm_sources" />
}

export const utmCampaignsRoute = {
  path: BREAKDOWN_REPORTS.utmCampaigns.detailsPath,
  element: <SourcesModal currentView="utm_campaigns" />
}

export const utmContentsRoute = {
  path: BREAKDOWN_REPORTS.utmContents.detailsPath,
  element: <SourcesModal currentView="utm_contents" />
}

export const utmTermsRoute = {
  path: BREAKDOWN_REPORTS.utmTerms.detailsPath,
  element: <SourcesModal currentView="utm_terms" />
}

export const referrersGoogleRoute = {
  path: 'referrers/Google',
  element: <GoogleKeywordsModal />
}

export const topPagesRoute = {
  path: BREAKDOWN_REPORTS.pages.detailsPath,
  element: <PagesDetails breakdownReportKey={BreakdownReportKey.pages} />
}

export const entryPagesRoute = {
  path: BREAKDOWN_REPORTS.entryPages.detailsPath,
  element: <PagesDetails breakdownReportKey={BreakdownReportKey.entryPages} />
}

export const exitPagesRoute = {
  path: BREAKDOWN_REPORTS.exitPages.detailsPath,
  element: <PagesDetails breakdownReportKey={BreakdownReportKey.exitPages} />
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
  path: BREAKDOWN_REPORTS.browsers.detailsPath,
  element: <DevicesDetails reportKey={BreakdownReportKey.browsers} />
}

export const browserVersionsRoute = {
  path: BREAKDOWN_REPORTS.browserVersions.detailsPath,
  element: <DevicesDetails reportKey={BreakdownReportKey.browserVersions} />
}

export const operatingSystemsRoute = {
  path: BREAKDOWN_REPORTS.operatingSystems.detailsPath,
  element: <DevicesDetails reportKey={BreakdownReportKey.operatingSystems} />
}

export const operatingSystemVersionsRoute = {
  path: BREAKDOWN_REPORTS.operatingSystemVersions.detailsPath,
  element: (
    <DevicesDetails reportKey={BreakdownReportKey.operatingSystemVersions} />
  )
}

export const screenSizesRoute = {
  path: BREAKDOWN_REPORTS.screenSizes.detailsPath,
  element: (
    <DevicesDetails
      reportKey={BreakdownReportKey.screenSizes}
      searchEnabled={false}
    />
  )
}

export const conversionsRoute = {
  path: 'conversions',
  element: <ConversionsModal />
}

export const referrersDrilldownRoute = {
  path: BREAKDOWN_REPORTS.referrers.detailsPath,
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
