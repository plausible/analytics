import React from 'react'
import { createBrowserRouter, Outlet, useRouteError } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

import { PlausibleSite, useSiteContext } from './site-context'
import {
  GoBackToDashboard,
  SomethingWentWrongMessage
} from './error/something-went-wrong'
import Dashboard from './index'
import GoogleKeywordsModal from './stats/modals/google-keywords'
import { PagesDetails } from './stats/pages/details'
import { DevicesDetails } from './stats/devices/details'
import {
  BREAKDOWN_REPORTS,
  BreakdownReportKey
} from './stats/reports/reports-config'
import { LocationsDetails } from './stats/locations/details'
import PropsModal from './stats/modals/props'
import ConversionsModal from './stats/modals/conversions'
import FilterModal from './stats/modals/filter-modal'
import DashboardStateContextProvider from './dashboard-state-context'
import { DashboardKeybinds } from './dashboard-keybinds'
import LastLoadContextProvider from './last-load-context'
import { RoutelessModalsContextProvider } from './navigation/routeless-modals-context'
import { RoutelessSegmentModals } from './segments/routeless-segment-modals'
import { GOOGLE_SEARCH_TERMS_DETAILS_PATH } from './stats/sources/fetch-search-terms'
import { SourcesDetails } from './stats/sources/details'

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
  element: <SourcesDetails reportKey={BreakdownReportKey.sources} />
}

export const channelsRoute = {
  path: BREAKDOWN_REPORTS.channels.detailsPath,
  element: <SourcesDetails reportKey={BreakdownReportKey.channels} />
}

export const utmMediumsRoute = {
  path: BREAKDOWN_REPORTS.utmMediums.detailsPath,
  element: <SourcesDetails reportKey={BreakdownReportKey.utmMediums} />
}

export const utmSourcesRoute = {
  path: BREAKDOWN_REPORTS.utmSources.detailsPath,
  element: <SourcesDetails reportKey={BreakdownReportKey.utmSources} />
}

export const utmCampaignsRoute = {
  path: BREAKDOWN_REPORTS.utmCampaigns.detailsPath,
  element: <SourcesDetails reportKey={BreakdownReportKey.utmCampaigns} />
}

export const utmContentsRoute = {
  path: BREAKDOWN_REPORTS.utmContents.detailsPath,
  element: <SourcesDetails reportKey={BreakdownReportKey.utmContents} />
}

export const utmTermsRoute = {
  path: BREAKDOWN_REPORTS.utmTerms.detailsPath,
  element: <SourcesDetails reportKey={BreakdownReportKey.utmTerms} />
}

export const referrersGoogleRoute = {
  path: GOOGLE_SEARCH_TERMS_DETAILS_PATH,
  element: <GoogleKeywordsModal />
}

export const topPagesRoute = {
  path: BREAKDOWN_REPORTS.pages.detailsPath,
  element: <PagesDetails breakdownReportKey={BreakdownReportKey.pages} />
}

export const topPagesWithHostnameRoute = {
  path: BREAKDOWN_REPORTS.pagesWithHostname.detailsPath,
  element: (
    <PagesDetails breakdownReportKey={BreakdownReportKey.pagesWithHostname} />
  )
}

export const entryPagesRoute = {
  path: BREAKDOWN_REPORTS.entryPages.detailsPath,
  element: <PagesDetails breakdownReportKey={BreakdownReportKey.entryPages} />
}

export const entryPagesWithHostnameRoute = {
  path: BREAKDOWN_REPORTS.entryPagesWithHostname.detailsPath,
  element: (
    <PagesDetails
      breakdownReportKey={BreakdownReportKey.entryPagesWithHostname}
    />
  )
}

export const exitPagesRoute = {
  path: BREAKDOWN_REPORTS.exitPages.detailsPath,
  element: <PagesDetails breakdownReportKey={BreakdownReportKey.exitPages} />
}

export const exitPagesWithHostnameRoute = {
  path: BREAKDOWN_REPORTS.exitPagesWithHostname.detailsPath,
  element: (
    <PagesDetails
      breakdownReportKey={BreakdownReportKey.exitPagesWithHostname}
    />
  )
}

export const countriesRoute = {
  path: BREAKDOWN_REPORTS.countries.detailsPath,
  element: <LocationsDetails reportKey={BreakdownReportKey.countries} />
}

export const regionsRoute = {
  path: BREAKDOWN_REPORTS.regions.detailsPath,
  element: <LocationsDetails reportKey={BreakdownReportKey.regions} />
}

export const citiesRoute = {
  path: BREAKDOWN_REPORTS.cities.detailsPath,
  element: <LocationsDetails reportKey={BreakdownReportKey.cities} />
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
  element: <SourcesDetails reportKey={BreakdownReportKey.referrers} />
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
          topPagesWithHostnameRoute,
          entryPagesRoute,
          entryPagesWithHostnameRoute,
          exitPagesRoute,
          exitPagesWithHostnameRoute,
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
