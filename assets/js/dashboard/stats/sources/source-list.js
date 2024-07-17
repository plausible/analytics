import React, { Fragment, useEffect, useState } from 'react';

import * as storage from '../../util/storage';
import * as url from '../../util/url';
import * as api from '../../api';
import ListReport from '../reports/list';
import * as metrics from '../reports/metrics';
import { hasGoalFilter } from "../../util/filters";
import { Menu, Transition } from '@headlessui/react';
import { ChevronDownIcon } from '@heroicons/react/20/solid';
import classNames from 'classnames';
import ImportedQueryUnsupportedWarning from '../imported-query-unsupported-warning';
import { useQueryContext } from '../../query-context';
import { useSiteContext } from '../../site-context';

const UTM_TAGS = {
  utm_medium: { label: 'UTM Medium', shortLabel: 'UTM Medium', endpoint: '/utm_mediums' },
  utm_source: { label: 'UTM Source', shortLabel: 'UTM Source', endpoint: '/utm_sources' },
  utm_campaign: { label: 'UTM Campaign', shortLabel: 'UTM Campai', endpoint: '/utm_campaigns' },
  utm_content: { label: 'UTM Content', shortLabel: 'UTM Conten', endpoint: '/utm_contents' },
  utm_term: { label: 'UTM Term', shortLabel: 'UTM Term', endpoint: '/utm_terms' },
}

function AllSources({ afterFetchData }) {
  const { query } = useQueryContext();
  const site = useSiteContext();

  function fetchData() {
    return api.get(url.apiPath(site, '/sources'), query, { limit: 9 })
  }

  function getFilterFor(listItem) {
    return {
      prefix: 'source',
      filter: ["is", "source", [listItem['name']]]
    }
  }

  function renderIcon(listItem) {
    return (
      <img
        src={`/favicon/sources/${encodeURIComponent(listItem.name)}`}
        className="w-4 h-4 mr-2"
      />
    )
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      hasGoalFilter(query) && metrics.createConversionRate(),
    ].filter(metric => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterFor={getFilterFor}
      keyLabel="Source"
      metrics={chooseMetrics()}
      detailsLink={url.sitePath('sources')}
      renderIcon={renderIcon}
      color="bg-blue-50"
    />
  )
}

function UTMSources({ tab, afterFetchData }) {
  const { query } = useQueryContext();
  const site = useSiteContext();
  const utmTag = UTM_TAGS[tab]

  function fetchData() {
    return api.get(url.apiPath(site, utmTag.endpoint), query, { limit: 9 })
  }

  function getFilterFor(listItem) {
    return {
      prefix: tab,
      filter: ["is", tab, [listItem['name']]]
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      hasGoalFilter(query) && metrics.createConversionRate(),
    ].filter(metric => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterFor={getFilterFor}
      keyLabel={utmTag.label}
      metrics={chooseMetrics()}
      detailsLink={url.sitePath(utmTag.endpoint)}
      color="bg-blue-50"
    />
  )
}

export default function SourceList() {
  const site = useSiteContext();
  const { query } = useQueryContext();
  const tabKey = 'sourceTab__' + site.domain
  const storedTab = storage.getItem(tabKey)
  const [currentTab, setCurrentTab] = useState(storedTab || 'all')
  const [loading, setLoading] = useState(true)
  const [skipImportedReason, setSkipImportedReason] = useState(null)

  useEffect(() => setLoading(true), [query, currentTab])

  function setTab(tab) {
    return () => {
      storage.setItem(tabKey, tab)
      setCurrentTab(tab)
    }
  }

  function renderTabs() {
    const activeClass = 'inline-block h-5 text-indigo-700 dark:text-indigo-500 font-bold active-prop-heading truncate text-left'
    const defaultClass = 'hover:text-indigo-600 cursor-pointer truncate text-left'
    const dropdownOptions = Object.keys(UTM_TAGS)
    let buttonText = UTM_TAGS[currentTab] ? UTM_TAGS[currentTab].label : 'Campaigns'

    return (
      <div className="flex text-xs font-medium text-gray-500 dark:text-gray-400 space-x-2">
        <div className={currentTab === 'all' ? activeClass : defaultClass} onClick={setTab('all')}>All</div>

        <Menu as="div" className="relative inline-block text-left">
          <div>
            <Menu.Button className="inline-flex justify-between focus:outline-none">
              <span className={currentTab.startsWith('utm_') ? activeClass : defaultClass}>{buttonText}</span>
              <ChevronDownIcon className="-mr-1 ml-1 h-4 w-4" aria-hidden="true" />
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
                            active ? 'bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-200 cursor-pointer' : 'text-gray-700 dark:text-gray-200',
                            'block px-4 py-2 text-sm',
                            currentTab === option ? 'font-bold' : ''
                          )}
                        >
                          {UTM_TAGS[option].label}
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

  function renderContent() {
    if (currentTab === 'all') {
      return <AllSources afterFetchData={afterFetchData} />
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
            Top Sources
          </h3>
          <ImportedQueryUnsupportedWarning loading={loading} skipImportedReason={skipImportedReason} />
        </div>
        {renderTabs()}
      </div>
      {/* Main Contents */}
      {renderContent()}
    </div>
  )
}
