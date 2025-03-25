import React, { Fragment, useEffect, useRef, useState } from 'react'

import * as storage from '../../util/storage'
import * as url from '../../util/url'
import * as api from '../../api'
import usePrevious from '../../hooks/use-previous'
import ListReport from '../reports/list'
import * as metrics from '../reports/metrics'
import {
  getFiltersByKeyPrefix,
  hasConversionGoalFilter
} from '../../util/filters'
import { Menu, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import ImportedQueryUnsupportedWarning from '../imported-query-unsupported-warning'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import {
  sourcesRoute,
  channelsRoute,
  utmCampaignsRoute,
  utmContentsRoute,
  utmMediumsRoute,
  utmSourcesRoute,
  utmTermsRoute
} from '../../router'
import { BlurMenuButtonOnEscape } from '../../keybinding'

const UTM_TAGS = {
  utm_medium: {
    title: 'UTM Mediums',
    label: 'Medium',
    endpoint: '/utm_mediums'
  },
  utm_source: {
    title: 'UTM Sources',
    label: 'Source',
    endpoint: '/utm_sources'
  },
  utm_campaign: {
    title: 'UTM Campaigns',
    label: 'Campaign',
    endpoint: '/utm_campaigns'
  },
  utm_content: {
    title: 'UTM Contents',
    label: 'Content',
    endpoint: '/utm_contents'
  },
  utm_term: { title: 'UTM Terms', label: 'Term', endpoint: '/utm_terms' }
}

function AllSources({ afterFetchData }) {
  const { query } = useQueryContext()
  const site = useSiteContext()
  function fetchData() {
    return api.get(url.apiPath(site, '/sources'), query, { limit: 9 })
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'source',
      filter: ['is', 'source', [listItem['name']]]
    }
  }

  function renderIcon(listItem) {
    return (
      <img
        alt=""
        src={`/favicon/sources/${encodeURIComponent(listItem.name)}`}
        className="w-4 h-4 mr-2"
      />
    )
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      hasConversionGoalFilter(query) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel="Source"
      metrics={chooseMetrics()}
      detailsLinkProps={{ path: sourcesRoute.path, search: (search) => search }}
      renderIcon={renderIcon}
      color="bg-blue-50"
    />
  )
}

function Channels({ onClick, afterFetchData }) {
  const { query } = useQueryContext()
  const site = useSiteContext()

  function fetchData() {
    return api.get(url.apiPath(site, '/channels'), query, { limit: 9 })
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'channel',
      filter: ['is', 'channel', [listItem['name']]]
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      hasConversionGoalFilter(query) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel="Channel"
      onClick={onClick}
      metrics={chooseMetrics()}
      detailsLinkProps={{
        path: channelsRoute.path,
        search: (search) => search
      }}
      color="bg-blue-50"
    />
  )
}

function UTMSources({ tab, afterFetchData }) {
  const { query } = useQueryContext()
  const site = useSiteContext()
  const utmTag = UTM_TAGS[tab]

  const route = {
    utm_medium: utmMediumsRoute,
    utm_source: utmSourcesRoute,
    utm_campaign: utmCampaignsRoute,
    utm_content: utmContentsRoute,
    utm_term: utmTermsRoute
  }[tab]

  function fetchData() {
    return api.get(url.apiPath(site, utmTag.endpoint), query, { limit: 9 })
  }

  function getFilterInfo(listItem) {
    return {
      prefix: tab,
      filter: ['is', tab, [listItem['name']]]
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      hasConversionGoalFilter(query) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel={utmTag.label}
      metrics={chooseMetrics()}
      detailsLinkProps={{ path: route?.path, search: (search) => search }}
      color="bg-blue-50"
    />
  )
}

const labelFor = {
  channels: 'Top Channels',
  all: 'Top Sources'
}

for (const [key, utm_tag] of Object.entries(UTM_TAGS)) {
  labelFor[key] = utm_tag.title
}

export default function SourceList() {
  const site = useSiteContext()
  const { query } = useQueryContext()
  const tabKey = 'sourceTab__' + site.domain
  const storedTab = storage.getItem(tabKey)
  const [currentTab, setCurrentTab] = useState(storedTab || 'all')
  const [loading, setLoading] = useState(true)
  const [skipImportedReason, setSkipImportedReason] = useState(null)
  const previousQuery = usePrevious(query)
  const dropdownButtonRef = useRef(null)

  useEffect(() => setLoading(true), [query, currentTab])

  useEffect(() => {
    const isRemovingFilter = (filterName) => {
      if (!previousQuery) return false

      return (
        getFiltersByKeyPrefix(previousQuery, filterName).length > 0 &&
        getFiltersByKeyPrefix(query, filterName).length == 0
      )
    }

    if (currentTab == 'all' && isRemovingFilter('channel')) {
      setTab('channels')()
    }
  }, [query, currentTab])

  function setTab(tab) {
    return () => {
      storage.setItem(tabKey, tab)
      setCurrentTab(tab)
    }
  }

  function renderTabs() {
    const activeClass =
      'inline-block h-5 text-indigo-700 dark:text-indigo-500 font-bold active-prop-heading truncate text-left'
    const defaultClass =
      'hover:text-indigo-600 cursor-pointer truncate text-left'
    const dropdownOptions = Object.keys(UTM_TAGS)
    let buttonText = UTM_TAGS[currentTab]
      ? UTM_TAGS[currentTab].title
      : 'Campaigns'

    return (
      <div className="flex text-xs font-medium text-gray-500 dark:text-gray-400 space-x-2">
        <div
          className={currentTab === 'channels' ? activeClass : defaultClass}
          onClick={setTab('channels')}
        >
          Channels
        </div>
        <div
          className={currentTab === 'all' ? activeClass : defaultClass}
          onClick={setTab('all')}
        >
          Sources
        </div>

        <Menu as="div" className="relative inline-block text-left">
          <BlurMenuButtonOnEscape targetRef={dropdownButtonRef} />
          <div>
            <Menu.Button
              className="inline-flex justify-between focus:outline-none"
              ref={dropdownButtonRef}
            >
              <span
                className={
                  currentTab.startsWith('utm_') ? activeClass : defaultClass
                }
              >
                {buttonText}
              </span>
              <ChevronDownIcon
                className="-mr-1 ml-1 h-4 w-4"
                aria-hidden="true"
              />
            </Menu.Button>
          </div>

          <Transition
            as={Fragment}
            enter="transition ease-out duration-100"
            enterFrom="opacity-0 scale-95"
            enterTo="opacity-100 scale-100"
            leave="transition ease-in duration-75"
            leaveFrom="opacity-100 scale-100"
            leaveTo="opacity-0 scale-95"
          >
            <Menu.Items className="text-left origin-top-right absolute right-0 mt-2 w-56 rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 focus:outline-none z-10">
              <div className="py-1">
                {dropdownOptions.map((option) => {
                  return (
                    <Menu.Item key={option}>
                      {({ active }) => (
                        <span
                          onClick={setTab(option)}
                          className={classNames(
                            active
                              ? 'bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-200 cursor-pointer'
                              : 'text-gray-700 dark:text-gray-200',
                            'block px-4 py-2 text-sm',
                            currentTab === option ? 'font-bold' : ''
                          )}
                        >
                          {UTM_TAGS[option].title}
                        </span>
                      )}
                    </Menu.Item>
                  )
                })}
              </div>
            </Menu.Items>
          </Transition>
        </Menu>
      </div>
    )
  }

  function onChannelClick() {
    setTab('all')()
  }

  function renderContent() {
    if (currentTab === 'all') {
      return <AllSources afterFetchData={afterFetchData} />
    } else if (currentTab == 'channels') {
      return (
        <Channels onClick={onChannelClick} afterFetchData={afterFetchData} />
      )
    } else {
      return <UTMSources tab={currentTab} afterFetchData={afterFetchData} />
    }
  }

  function afterFetchData(apiResponse) {
    setLoading(false)
    setSkipImportedReason(apiResponse.skip_imported_reason)
  }

  return (
    <div>
      {/* Header Container */}
      <div className="w-full flex justify-between">
        <div className="flex gap-x-1">
          <h3 className="font-bold dark:text-gray-100">
            {labelFor[currentTab]}
          </h3>
          <ImportedQueryUnsupportedWarning
            loading={loading}
            skipImportedReason={skipImportedReason}
          />
        </div>
        {renderTabs()}
      </div>
      {/* Main Contents */}
      {renderContent()}
    </div>
  )
}
