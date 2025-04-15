import React, { useEffect, useState } from 'react'

import * as storage from '../../util/storage'
import * as url from '../../util/url'
import * as api from '../../api'
import ListReport from './../reports/list'
import * as metrics from './../reports/metrics'
import ImportedQueryUnsupportedWarning from '../imported-query-unsupported-warning'
import { hasConversionGoalFilter } from '../../util/filters'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import { entryPagesRoute, exitPagesRoute, topPagesRoute } from '../../router'
import { TabButton, TabWrapper } from '../../components/tabs'

function EntryPages({ afterFetchData }) {
  const { query } = useQueryContext()
  const site = useSiteContext()
  function fetchData() {
    return api.get(url.apiPath(site, '/entry-pages'), query, { limit: 9 })
  }

  function getExternalLinkUrl(page) {
    return url.externalLinkForPage(site.domain, page.name)
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'entry_page',
      filter: ['is', 'entry_page', [listItem['name']]]
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({
        defaultLabel: 'Unique Entrances',
        width: 'w-36',
        meta: { plot: true }
      }),
      hasConversionGoalFilter(query) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel="Entry page"
      metrics={chooseMetrics()}
      detailsLinkProps={{
        path: entryPagesRoute.path,
        search: (search) => search
      }}
      getExternalLinkUrl={getExternalLinkUrl}
      color="bg-orange-50"
    />
  )
}

function ExitPages({ afterFetchData }) {
  const site = useSiteContext()
  const { query } = useQueryContext()
  function fetchData() {
    return api.get(url.apiPath(site, '/exit-pages'), query, { limit: 9 })
  }

  function getExternalLinkUrl(page) {
    return url.externalLinkForPage(site.domain, page.name)
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'exit_page',
      filter: ['is', 'exit_page', [listItem['name']]]
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({
        defaultLabel: 'Unique Exits',
        width: 'w-36',
        meta: { plot: true }
      }),
      hasConversionGoalFilter(query) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel="Exit page"
      metrics={chooseMetrics()}
      detailsLinkProps={{
        path: exitPagesRoute.path,
        search: (search) => search
      }}
      getExternalLinkUrl={getExternalLinkUrl}
      color="bg-orange-50"
    />
  )
}

function TopPages({ afterFetchData }) {
  const { query } = useQueryContext()
  const site = useSiteContext()
  function fetchData() {
    return api.get(url.apiPath(site, '/pages'), query, { limit: 9 })
  }

  function getExternalLinkUrl(page) {
    return url.externalLinkForPage(site.domain, page.name)
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'page',
      filter: ['is', 'page', [listItem['name']]]
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
      keyLabel="Page"
      metrics={chooseMetrics()}
      detailsLinkProps={{
        path: topPagesRoute.path,
        search: (search) => search
      }}
      getExternalLinkUrl={getExternalLinkUrl}
      color="bg-orange-50"
    />
  )
}

const labelFor = {
  pages: 'Top Pages',
  'entry-pages': 'Entry Pages',
  'exit-pages': 'Exit Pages'
}

export default function Pages() {
  const { query } = useQueryContext()
  const site = useSiteContext()

  const tabKey = `pageTab__${site.domain}`
  const storedTab = storage.getItem(tabKey)
  const [mode, setMode] = useState(storedTab || 'pages')
  const [loading, setLoading] = useState(true)
  const [skipImportedReason, setSkipImportedReason] = useState(null)

  function switchTab(mode) {
    storage.setItem(tabKey, mode)
    setMode(mode)
  }

  function afterFetchData(apiResponse) {
    setLoading(false)
    setSkipImportedReason(apiResponse.skip_imported_reason)
  }

  useEffect(() => setLoading(true), [query, mode])

  function renderContent() {
    switch (mode) {
      case 'entry-pages':
        return <EntryPages afterFetchData={afterFetchData} />
      case 'exit-pages':
        return <ExitPages afterFetchData={afterFetchData} />
      case 'pages':
      default:
        return <TopPages afterFetchData={afterFetchData} />
    }
  }

  return (
    <div>
      {/* Header Container */}
      <div className="w-full flex justify-between">
        <div className="flex gap-x-1">
          <h3 className="font-bold dark:text-gray-100">
            {labelFor[mode] || 'Page Visits'}
          </h3>
          <ImportedQueryUnsupportedWarning
            loading={loading}
            skipImportedReason={skipImportedReason}
          />
        </div>
        <TabWrapper>
          {[
            { label: 'Top Pages', value: 'pages' },
            { label: 'Entry Pages', value: 'entry-pages' },
            { label: 'Exit Pages', value: 'exit-pages' }
          ].map(({ value, label }) => (
            <TabButton
              active={mode === value}
              onClick={() => switchTab(value)}
              key={value}
            >
              {label}
            </TabButton>
          ))}
        </TabWrapper>
      </div>
      {/* Main Contents */}
      {renderContent()}
    </div>
  )
}
