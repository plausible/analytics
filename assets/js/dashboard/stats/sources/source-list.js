import React, { Fragment, useState } from 'react';

import * as storage from '../../util/storage'
import * as url from '../../util/url'
import * as api from '../../api'
import ListReport from '../reports/list'
import { VISITORS_METRIC, maybeWithCR } from '../reports/metrics';
import { Menu, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'

const UTM_TAGS = {
  utm_medium: { label: 'UTM Medium', shortLabel: 'UTM Medium', endpoint: '/utm_mediums' },
  utm_source: { label: 'UTM Source', shortLabel: 'UTM Source', endpoint: '/utm_sources' },
  utm_campaign: { label: 'UTM Campaign', shortLabel: 'UTM Campai', endpoint: '/utm_campaigns' },
  utm_content: { label: 'UTM Content', shortLabel: 'UTM Conten', endpoint: '/utm_contents' },
  utm_term: { label: 'UTM Term', shortLabel: 'UTM Term', endpoint: '/utm_terms' },
}

function AllSources(props) {
  const { site, query } = props

  function fetchData() {
    return api.get(url.apiPath(site, '/sources'), query, { limit: 9 })
  }

  function getFilterFor(listItem) {
    return { source: listItem['name'] }
  }

  function renderIcon(listItem) {
    return (
      <img
        src={`/favicon/sources/${encodeURIComponent(listItem.name)}`}
        className="inline w-4 h-4 mr-2 -mt-px align-middle"
      />
    )
  }

  return (
    <ListReport
      fetchData={fetchData}
      getFilterFor={getFilterFor}
      keyLabel="Source"
      metrics={maybeWithCR([VISITORS_METRIC], query)}
      detailsLink={url.sitePath(site, '/sources')}
      renderIcon={renderIcon}
      query={query}
      color="bg-blue-50"
    />
  )
}

function UTMSources(props) {
  const { site, query } = props
  const utmTag = UTM_TAGS[props.tab]

  function fetchData() {
    return api.get(url.apiPath(site, utmTag.endpoint), query, { limit: 9 })
  }

  function getFilterFor(listItem) {
    return { [props.tab]: listItem['name'] }
  }

  return (
    <ListReport
      fetchData={fetchData}
      getFilterFor={getFilterFor}
      keyLabel={utmTag.label}
      metrics={maybeWithCR([VISITORS_METRIC], query)}
      detailsLink={url.sitePath(site, utmTag.endpoint)}
      query={query}
      color="bg-blue-50"
    />
  )
}

export default function SourceList(props) {
  const { site, query } = props
  const tabKey = 'sourceTab__' + props.site.domain
  const storedTab = storage.getItem(tabKey)
  const [currentTab, setCurrentTab] = useState(storedTab || 'all')

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
      return <AllSources site={site} query={query} />
    } else {
      return <UTMSources tab={currentTab} site={site} query={query} />
    }
  }

  return (
    <div>
      {/* Header Container */}
      <div className="w-full flex justify-between">
        <h3 className="font-bold dark:text-gray-100">
          Top Sources
        </h3>
        {renderTabs()}
      </div>
      {/* Main Contents */}
      {renderContent()}
    </div>
  )
}
