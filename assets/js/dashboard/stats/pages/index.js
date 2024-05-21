import React, { useState } from 'react';

import * as storage from '../../util/storage'
import * as url from '../../util/url'
import * as api from '../../api'
import ListReport from './../reports/list'
import { VISITORS_METRIC, maybeWithCR } from './../reports/metrics';

function EntryPages({ query, site }) {
  function fetchData() {
    return api.get(url.apiPath(site, '/entry-pages'), query, { limit: 9 })
  }

  function externalLinkDest(page) {
    return url.externalLinkForPage(site.domain, page.name)
  }

  function getFilterFor(listItem) {
    return {
      prefix: 'entry_page',
      filter: ["is", "entry_page", [listItem['name']]]
    }
  }

  return (
    <ListReport
      fetchData={fetchData}
      getFilterFor={getFilterFor}
      keyLabel="Entry page"
      metrics={maybeWithCR([{ ...VISITORS_METRIC, label: 'Unique Entrances' }], query)}
      detailsLink={url.sitePath(site, '/entry-pages')}
      query={query}
      externalLinkDest={externalLinkDest}
      color="bg-orange-50"
    />
  )
}

function ExitPages({ query, site }) {
  function fetchData() {
    return api.get(url.apiPath(site, '/exit-pages'), query, { limit: 9 })
  }

  function externalLinkDest(page) {
    return url.externalLinkForPage(site.domain, page.name)
  }

  function getFilterFor(listItem) {
    return {
      prefix: 'exit_page',
      filter: ["is", "exit_page", [listItem['name']]]
    }
  }

  return (
    <ListReport
      fetchData={fetchData}
      getFilterFor={getFilterFor}
      keyLabel="Exit page"
      metrics={maybeWithCR([{ ...VISITORS_METRIC, label: "Unique Exits" }], query)}
      detailsLink={url.sitePath(site, '/exit-pages')}
      query={query}
      externalLinkDest={externalLinkDest}
      color="bg-orange-50"
    />
  )
}

function TopPages({ query, site }) {
  function fetchData() {
    return api.get(url.apiPath(site, '/pages'), query, { limit: 9 })
  }

  function externalLinkDest(page) {
    return url.externalLinkForPage(site.domain, page.name)
  }

  function getFilterFor(listItem) {
    return {
      prefix: 'page',
      filter: ["is", "page", [listItem['name']]]
    }
  }

  return (
    <ListReport
      fetchData={fetchData}
      getFilterFor={getFilterFor}
      keyLabel="Page"
      metrics={maybeWithCR([VISITORS_METRIC], query)}
      detailsLink={url.sitePath(site, '/pages')}
      query={query}
      externalLinkDest={externalLinkDest}
      color="bg-orange-50"
    />
  )
}

const labelFor = {
  'pages': 'Top Pages',
  'entry-pages': 'Entry Pages',
  'exit-pages': 'Exit Pages',
}

export default function Pages(props) {
  const {site, query} = props
  const tabKey = `pageTab__${site.domain}`
  const storedTab = storage.getItem(tabKey)
  const [mode, setMode] = useState(storedTab || 'pages')

  function switchTab(mode) {
    storage.setItem(tabKey, mode)
    setMode(mode)
  }

  function renderContent() {
    switch (mode) {
      case "entry-pages":
        return <EntryPages site={site} query={query} />
      case "exit-pages":
        return <ExitPages site={site} query={query} />
      case "pages":
      default:
        return <TopPages site={site} query={query} />
    }
  }


  function renderPill(name, pill) {
    const isActive = mode === pill

    if (isActive) {
      return (
        <button
          className="inline-block h-5 text-indigo-700 dark:text-indigo-500 font-bold active-prop-heading"
        >
          {name}
        </button>
      )
    }

    return (
      <button
        className="hover:text-indigo-600 cursor-pointer"
        onClick={() => switchTab(pill)}
      >
        {name}
      </button>
    )
  }

  return (
    <div>
      {/* Header Container */}
      <div className="w-full flex justify-between">
        <h3 className="font-bold dark:text-gray-100">
          {labelFor[mode] || 'Page Visits'}
        </h3>
        <div className="flex font-medium text-xs text-gray-500 dark:text-gray-400 space-x-2">
          {renderPill('Top Pages', 'pages')}
          {renderPill('Entry Pages', 'entry-pages')}
          {renderPill('Exit Pages', 'exit-pages')}
        </div>
      </div>
      {/* Main Contents */}
      {renderContent()}
    </div>
  )
}
