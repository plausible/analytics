import React, { useEffect, useState } from 'react'
import * as storage from '../../util/storage'
import {
  getFiltersByKeyPrefix,
  hasConversionGoalFilter,
  isFilteringOnFixedValue
} from '../../util/filters'
import ListReport from '../reports/list'
import * as metrics from '../reports/metrics'
import * as api from '../../api'
import * as url from '../../util/url'
import ImportedQueryUnsupportedWarning from '../imported-query-unsupported-warning'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { ReportLayout } from '../reports/report-layout'
import { ReportHeader } from '../reports/report-header'
import { TabButton, TabWrapper } from '../../components/tabs'
import {
  browsersRoute,
  browserVersionsRoute,
  operatingSystemsRoute,
  operatingSystemVersionsRoute,
  screenSizesRoute
} from '../../router'
import MoreLink from '../more-link'
import { MoreLinkState } from '../more-link-state'

// Icons copied from https://github.com/alrra/browser-logos
const BROWSER_ICONS = {
  Chrome: 'chrome.svg',
  curl: 'curl.svg',
  Safari: 'safari.png',
  Firefox: 'firefox.svg',
  'Microsoft Edge': 'edge.svg',
  Vivaldi: 'vivaldi.svg',
  Opera: 'opera.svg',
  'Samsung Browser': 'samsung-internet.svg',
  Chromium: 'chromium.svg',
  'UC Browser': 'uc.svg',
  'Yandex Browser': 'yandex.png', // Only PNG available in browser-logos
  // Logos underneath this line are not available in browser-logos. Grabbed from random places on the internets.
  'DuckDuckGo Privacy Browser': 'duckduckgo.svg',
  'MIUI Browser': 'miui.webp',
  'Huawei Browser Mobile': 'huawei.png',
  'QQ Browser': 'qq.png',
  Ecosia: 'ecosia.png',
  'vivo Browser': 'vivo.png'
}

export function browserIconFor(browser) {
  const filename = BROWSER_ICONS[browser] || 'fallback.svg'

  return (
    <img
      alt=""
      src={`/images/icon/browser/${filename}`}
      className="w-4 h-4 mr-2"
    />
  )
}

function Browsers({ afterFetchData }) {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  function fetchData() {
    return api.get(url.apiPath(site, '/browsers'), dashboardState)
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'browser',
      filter: ['is', 'browser', [listItem['name']]]
    }
  }

  function renderIcon(listItem) {
    return browserIconFor(listItem.name)
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      !hasConversionGoalFilter(dashboardState) &&
        metrics.createPercentage({ meta: { showOnHover: true } }),
      hasConversionGoalFilter(dashboardState) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel="Browser"
      metrics={chooseMetrics()}
      renderIcon={renderIcon}
    />
  )
}

function BrowserVersions({ afterFetchData }) {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()
  function fetchData() {
    return api.get(url.apiPath(site, '/browser-versions'), dashboardState)
  }

  function renderIcon(listItem) {
    return browserIconFor(listItem.browser)
  }

  function getFilterInfo(listItem) {
    if (getSingleFilter(dashboardState, 'browser') == '(not set)') {
      return null
    }
    return {
      prefix: 'browser_version',
      filter: ['is', 'browser_version', [listItem.version]]
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      !hasConversionGoalFilter(dashboardState) &&
        metrics.createPercentage({ meta: { showOnHover: true } }),
      hasConversionGoalFilter(dashboardState) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel="Browser version"
      metrics={chooseMetrics()}
      renderIcon={renderIcon}
    />
  )
}

// Icons copied from https://github.com/ngeenx/operating-system-logos
const OS_ICONS = {
  iOS: 'ios.png',
  Mac: 'mac.png',
  Windows: 'windows.png',
  'Windows Phone': 'windows.png',
  Android: 'android.png',
  'GNU/Linux': 'gnu_linux.png',
  Ubuntu: 'ubuntu.png',
  'Chrome OS': 'chrome_os.png',
  iPadOS: 'ipad_os.png',
  'Fire OS': 'fire_os.png',
  HarmonyOS: 'harmony_os.png',
  Tizen: 'tizen.png',
  PlayStation: 'playstation.png',
  KaiOS: 'kai_os.png',
  Fedora: 'fedora.png',
  FreeBSD: 'freebsd.png'
}

export function osIconFor(os) {
  const filename = OS_ICONS[os] || 'fallback.svg'

  return (
    <img alt="" src={`/images/icon/os/${filename}`} className="w-4 h-4 mr-2" />
  )
}

function OperatingSystems({ afterFetchData }) {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()
  function fetchData() {
    return api.get(url.apiPath(site, '/operating-systems'), dashboardState)
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'os',
      filter: ['is', 'os', [listItem['name']]]
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      !hasConversionGoalFilter(dashboardState) &&
        metrics.createPercentage({
          meta: { showOnHover: true }
        }),
      hasConversionGoalFilter(dashboardState) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  function renderIcon(listItem) {
    return osIconFor(listItem.name)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      renderIcon={renderIcon}
      keyLabel="Operating system"
      metrics={chooseMetrics()}
    />
  )
}

function OperatingSystemVersions({ afterFetchData }) {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  function fetchData() {
    return api.get(
      url.apiPath(site, '/operating-system-versions'),
      dashboardState
    )
  }

  function renderIcon(listItem) {
    return osIconFor(listItem.os)
  }

  function getFilterInfo(listItem) {
    if (getSingleFilter(dashboardState, 'os') == '(not set)') {
      return null
    }
    return {
      prefix: 'os_version',
      filter: ['is', 'os_version', [listItem.version]]
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      !hasConversionGoalFilter(dashboardState) &&
        metrics.createPercentage({ meta: { showOnHover: true } }),
      hasConversionGoalFilter(dashboardState) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      renderIcon={renderIcon}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel="Operating system version"
      metrics={chooseMetrics()}
    />
  )
}

function ScreenSizes({ afterFetchData }) {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  function fetchData() {
    return api.get(url.apiPath(site, '/screen-sizes'), dashboardState)
  }

  function renderIcon(listItem) {
    return screenSizeIconFor(listItem.name)
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'screen',
      filter: ['is', 'screen', [listItem['name']]]
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      !hasConversionGoalFilter(dashboardState) &&
        metrics.createPercentage({ meta: { showOnHover: true } }),
      hasConversionGoalFilter(dashboardState) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel="Device"
      metrics={chooseMetrics()}
      renderIcon={renderIcon}
    />
  )
}

export function screenSizeIconFor(screenSize) {
  let svg = null

  if (screenSize === 'Mobile') {
    svg = (
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="24"
        height="24"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="-mt-px feather"
      >
        <rect x="5" y="2" width="14" height="20" rx="2" ry="2" />
        <line x1="12" y1="18" x2="12" y2="18" />
      </svg>
    )
  } else if (screenSize === 'Tablet') {
    svg = (
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="24"
        height="24"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="-mt-px feather"
      >
        <rect
          x="4"
          y="2"
          width="16"
          height="20"
          rx="2"
          ry="2"
          transform="rotate(180 12 12)"
        />
        <line x1="12" y1="18" x2="12" y2="18" />
      </svg>
    )
  } else if (screenSize === 'Laptop') {
    svg = (
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="24"
        height="24"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="-mt-px feather"
      >
        <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
        <line x1="2" y1="20" x2="22" y2="20" />
      </svg>
    )
  } else if (screenSize === 'Desktop') {
    svg = (
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="24"
        height="24"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="-mt-px feather"
      >
        <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
        <line x1="8" y1="21" x2="16" y2="21" />
        <line x1="12" y1="17" x2="12" y2="21" />
      </svg>
    )
  } else if (screenSize === 'Ultra-wide') {
    svg = (
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="24"
        height="24"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="-mt-px feather"
      >
        <rect x="1" y="4" width="22" height="12" rx="2" ry="2" />
        <line x1="6" y1="20" x2="18" y2="20" />
        <line x1="12" y1="16" x2="12" y2="20" />
      </svg>
    )
  } else if (screenSize === '(not set)') {
    svg = (
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        className="-mt-px feather"
      >
        <circle cx="12" cy="12" r="10" />
        <circle cx="12" cy="17.25" r="1.25" />
        <path d="M9.244 8.369c.422-1.608 1.733-2.44 3.201-2.364 1.45.075 2.799.872 2.737 2.722-.089 2.63-2.884 2.273-3.197 4.773h.011" />
      </svg>
    )
  }

  return <span className="mr-1.5">{svg}</span>
}

export default function Devices() {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  const tabKey = `deviceTab__${site.domain}`
  const storedTab = storage.getItem(tabKey)
  const [mode, setMode] = useState(storedTab || 'browser')
  const [loading, setLoading] = useState(true)
  const [skipImportedReason, setSkipImportedReason] = useState(null)
  const [moreLinkState, setMoreLinkState] = useState(MoreLinkState.LOADING)

  function switchTab(mode) {
    storage.setItem(tabKey, mode)
    setMode(mode)
  }

  function afterFetchData(apiResponse) {
    setLoading(false)
    setSkipImportedReason(apiResponse.skip_imported_reason)
    if (apiResponse.results && apiResponse.results.length > 0) {
      setMoreLinkState(MoreLinkState.READY)
    } else {
      setMoreLinkState(MoreLinkState.HIDDEN)
    }
  }

  useEffect(() => {
    setLoading(true)
    setMoreLinkState(MoreLinkState.LOADING)
  }, [dashboardState, mode])

  function moreLinkProps() {
    switch (mode) {
      case 'browser':
        if (isFilteringOnFixedValue(dashboardState, 'browser')) {
          return {
            path: browserVersionsRoute.path,
            search: (search) => search
          }
        }
        return {
          path: browsersRoute.path,
          search: (search) => search
        }
      case 'os':
        if (isFilteringOnFixedValue(dashboardState, 'os')) {
          return {
            path: operatingSystemVersionsRoute.path,
            search: (search) => search
          }
        }
        return {
          path: operatingSystemsRoute.path,
          search: (search) => search
        }
      case 'size':
      default:
        return {
          path: screenSizesRoute.path,
          search: (search) => search
        }
    }
  }

  function renderContent() {
    switch (mode) {
      case 'browser':
        if (isFilteringOnFixedValue(dashboardState, 'browser')) {
          return <BrowserVersions afterFetchData={afterFetchData} />
        }
        return <Browsers afterFetchData={afterFetchData} />
      case 'os':
        if (isFilteringOnFixedValue(dashboardState, 'os')) {
          return <OperatingSystemVersions afterFetchData={afterFetchData} />
        }
        return <OperatingSystems afterFetchData={afterFetchData} />
      case 'size':
      default:
        return <ScreenSizes afterFetchData={afterFetchData} />
    }
  }

  return (
    <ReportLayout testId="report-devices" className="overflow-x-hidden">
      <ReportHeader>
        <div className="flex gap-x-3">
          <TabWrapper>
            {[
              { label: 'Browsers', value: 'browser' },
              { label: 'Operating systems', value: 'os' },
              { label: 'Devices', value: 'size' }
            ].map(({ label, value }) => (
              <TabButton
                key={value}
                active={mode === value}
                onClick={() => switchTab(value)}
              >
                {label}
              </TabButton>
            ))}
          </TabWrapper>
          <ImportedQueryUnsupportedWarning
            loading={loading}
            skipImportedReason={skipImportedReason}
          />
        </div>
        <MoreLink state={moreLinkState} linkProps={moreLinkProps()} />
      </ReportHeader>
      {renderContent()}
    </ReportLayout>
  )
}

function getSingleFilter(dashboardState, filterKey) {
  const matches = getFiltersByKeyPrefix(dashboardState, filterKey)
  if (matches.length != 1) {
    return null
  }
  const clauses = matches[0][2]

  return clauses.length == 1 ? clauses[0] : null
}
