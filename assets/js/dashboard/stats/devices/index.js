import React, { useEffect, useState } from 'react';
import * as storage from '../../util/storage';
import { getFiltersByKeyPrefix } from '../../util/filters';
import ListReport from '../reports/list';
import * as metrics from '../reports/metrics';
import * as api from '../../api';
import * as url from '../../util/url';
import ImportedQueryUnsupportedWarning from '../imported-query-unsupported-warning';
import { useQueryContext } from '../../query-context';
import { useSiteContext } from '../../site-context';
import {
  browsersRoute,
  browserVersionsRoute,
  operatingSystemsRoute,
  operatingSystemVersionsRoute,
  screenSizesRoute
} from '../../router';

// Icons copied from https://github.com/alrra/browser-logos
const BROWSER_ICONS = {
  'Chrome': 'chrome.svg',
  'curl': 'curl.svg',
  'Safari': 'safari.png',
  'Firefox': 'firefox.svg',
  'Microsoft Edge': 'edge.svg',
  'Vivaldi': 'vivaldi.svg',
  'Opera': 'opera.svg',
  'Samsung Browser': 'samsung-internet.svg',
  'Chromium': 'chromium.svg',
  'UC Browser': 'uc.svg',
  'Yandex Browser': 'yandex.png', // Only PNG available in browser-logos
  // Logos underneath this line are not available in browser-logos. Grabbed from random places on the internets.
  'DuckDuckGo Privacy Browser': 'duckduckgo.svg',
  'MIUI Browser': 'miui.webp',
  'Huawei Browser Mobile': 'huawei.png',
  'QQ Browser': 'qq.png',
  'Ecosia': 'ecosia.png',
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

function chooseMetrics({situation}) {
  return [
    metrics.createVisitors({ meta: { plot: true } }),
    situation.is_filtering_on_goal && metrics.createConversionRate(),
    !situation.is_filtering_on_goal && metrics.createPercentage()
  ].filter(metric => !!metric)
}

function chooseOperatingSystemMetrics({situation}) {
  return [
    metrics.createVisitors({ meta: { plot: true } }),
    situation.is_filtering_on_goal && metrics.createConversionRate(),
    !situation.is_filtering_on_goal && metrics.createPercentage({ meta: { hiddenonMobile: true } })
  ].filter(metric => !!metric)
}


function Browsers({ afterFetchData }) {
  const site = useSiteContext();
  const { query } = useQueryContext();
  function fetchData() {
    return api.get(url.apiPath(site, '/browsers'), query)
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'browser',
      filter: ["is", "browser", [listItem['name']]]
    }
  }

  function renderIcon(listItem) {
    return browserIconFor(listItem.name)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel="Browser"
      getMetrics={chooseMetrics}
      renderIcon={renderIcon}
      detailsLinkProps={{ path: browsersRoute.path, search: (search) => search }}
    />
  )
}

function BrowserVersions({ afterFetchData }) {
  const { query } = useQueryContext();
  const site = useSiteContext();
  function fetchData() {
    return api.get(url.apiPath(site, '/browser-versions'), query)
  }

  function renderIcon(listItem) {
    return browserIconFor(listItem.browser)
  }

  function getFilterInfo(listItem) {
    if (getSingleFilter(query, "browser") == '(not set)') {
      return null
    }
    return {
      prefix: 'browser_version',
      filter: ["is", "browser_version", [listItem.version]]
    }
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel="Browser version"
      getMetrics={chooseMetrics}
      renderIcon={renderIcon}
      detailsLinkProps={{ path: browserVersionsRoute.path, search: (search) => search }}
    />
  )
}

// Icons copied from https://github.com/ngeenx/operating-system-logos
const OS_ICONS = {
  'iOS': 'ios.png',
  'Mac': 'mac.png',
  'Windows': 'windows.png',
  'Windows Phone': 'windows.png',
  'Android': 'android.png',
  'GNU/Linux': 'gnu_linux.png',
  'Ubuntu': 'ubuntu.png',
  'Chrome OS': 'chrome_os.png',
  'iPadOS': 'ipad_os.png',
  'Fire OS': 'fire_os.png',
  'HarmonyOS': 'harmony_os.png',
  'Tizen': 'tizen.png',
  'PlayStation': 'playstation.png',
  'KaiOS': 'kai_os.png',
  'Fedora': 'fedora.png',
  'FreeBSD': 'freebsd.png',
}

export function osIconFor(os) {
  const filename = OS_ICONS[os] || 'fallback.svg'

  return (
    <img
      alt=""
      src={`/images/icon/os/${filename}`}
      className="w-4 h-4 mr-2"
    />
  )
}

function OperatingSystems({ afterFetchData }) {
  const { query } = useQueryContext();
  const site = useSiteContext();
  function fetchData() {
    return api.get(url.apiPath(site, '/operating-systems'), query)
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'os',
      filter: ["is", "os", [listItem['name']]]
    }
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
      getMetrics={chooseOperatingSystemMetrics}
      detailsLinkProps={{ path: operatingSystemsRoute.path, search: (search) => search }}
    />
  )
}

function OperatingSystemVersions({ afterFetchData }) {
  const { query } = useQueryContext();
  const site = useSiteContext();

  function fetchData() {
    return api.get(url.apiPath(site, '/operating-system-versions'), query)
  }

  function renderIcon(listItem) {
    return osIconFor(listItem.os)
  }

  function getFilterInfo(listItem) {
    if (getSingleFilter(query, "os") == '(not set)') {
      return null
    }
    return {
      prefix: 'os_version',
      filter: ["is", "os_version", [listItem.version]]
    }
  }

  return (
    <ListReport
      fetchData={fetchData}
      renderIcon={renderIcon}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel="Operating System Version"
      getMetrics={chooseMetrics}
      detailsLinkProps={{ path: operatingSystemVersionsRoute.path, search: (search) => search }}
    />
  )

}

function ScreenSizes({ afterFetchData }) {
  const { query } = useQueryContext();
  const site = useSiteContext();

  function fetchData() {
    return api.get(url.apiPath(site, '/screen-sizes'), query)
  }

  function renderIcon(listItem) {
    return screenSizeIconFor(listItem.name)
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'screen',
      filter: ["is", "screen", [listItem['name']]]
    }
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel="Screen size"
      getMetrics={chooseMetrics}
      renderIcon={renderIcon}
      detailsLinkProps={{ path: screenSizesRoute.path, search: (search) => search }}
    />
  )
}

export function screenSizeIconFor(screenSize) {
  let svg = null

  if (screenSize === 'Mobile') {
    svg = <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="-mt-px feather"><rect x="5" y="2" width="14" height="20" rx="2" ry="2" /><line x1="12" y1="18" x2="12" y2="18" /></svg>
  } else if (screenSize === 'Tablet') {
    svg = <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="-mt-px feather"><rect x="4" y="2" width="16" height="20" rx="2" ry="2" transform="rotate(180 12 12)" /><line x1="12" y1="18" x2="12" y2="18" /></svg>
  } else if (screenSize === 'Laptop') {
    svg = <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="-mt-px feather"><rect x="2" y="3" width="20" height="14" rx="2" ry="2" /><line x1="2" y1="20" x2="22" y2="20" /></svg>
  } else if (screenSize === 'Desktop') {
    svg = <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="-mt-px feather"><rect x="2" y="3" width="20" height="14" rx="2" ry="2" /><line x1="8" y1="21" x2="16" y2="21" /><line x1="12" y1="17" x2="12" y2="21" /></svg>
  }

  return <span className="mr-1.5">{svg}</span>
}

export default function Devices() {
  const { query } = useQueryContext();
  const site = useSiteContext();

  const tabKey = `deviceTab__${site.domain}`
  const storedTab = storage.getItem(tabKey)
  const [mode, setMode] = useState(storedTab || 'browser')
  const [loading, setLoading] = useState(true)
  const [skipImportedReason, setSkipImportedReason] = useState(null)
  const [meta, setMeta] = useState(null);

  function switchTab(mode) {
    storage.setItem(tabKey, mode)
    setMode(mode)
  }

  function afterFetchData(apiResponse) {
    setLoading(false)
    setSkipImportedReason(apiResponse.skip_imported_reason)
    setMeta(apiResponse.meta)
  }

  useEffect(() => setLoading(true), [query, mode])

  function renderContent() {
    switch (mode) {
      case 'browser':
        if (meta?.situation?.fixed_browser) {
          return <BrowserVersions afterFetchData={afterFetchData} />
        }
        return <Browsers afterFetchData={afterFetchData} />
      case 'os':
        if (meta?.situation?.fixed_os) {
          return <OperatingSystemVersions afterFetchData={afterFetchData} />
        }
        return <OperatingSystems afterFetchData={afterFetchData} />
      case 'size':
      default:
        return <ScreenSizes afterFetchData={afterFetchData} />
    }
  }

  function renderPill(name, pill) {
    const isActive = mode === pill

    if (isActive) {
      return (
        <button
          className="inline-block h-5 font-bold text-indigo-700 active-prop-heading dark:text-indigo-500"
        >
          {name}
        </button>
      )
    }

    return (
      <button
        className="cursor-pointer hover:text-indigo-600"
        onClick={() => switchTab(pill)}
      >
        {name}
      </button>
    )
  }

  return (
    <div>
      <div className="flex justify-between w-full">
        <div className="flex gap-x-1">
          <h3 className="font-bold dark:text-gray-100">Devices</h3>
          <ImportedQueryUnsupportedWarning loading={loading} skipImportedReason={skipImportedReason} />
        </div>
        <div className="flex text-xs font-medium text-gray-500 dark:text-gray-400 space-x-2">
          {renderPill('Browser', 'browser')}
          {renderPill('OS', 'os')}
          {renderPill('Size', 'size')}
        </div>
      </div>
      {renderContent()}
    </div>
  )
}

function getSingleFilter(query, filterKey) {
  const matches = getFiltersByKeyPrefix(query, filterKey)
  if (matches.length != 1) {
    return null
  }
  const clauses = matches[0][2]

  return clauses.length == 1 ? clauses[0] : null
}
