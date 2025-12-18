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
import { ReportLayout } from '../reports/report-layout'
import { ReportHeader } from '../reports/report-header'
import { TabButton, TabWrapper } from '../../components/tabs'
import { useMoreLinkData } from '../../hooks/use-more-link-data'
import MoreLink from '../more-link'

function EntryPages({ afterFetchData, onListUpdate }) {
  const { query } = useQueryContext()
  const site = useSiteContext()
  function fetchData() {
    return api.get(url.apiPath(site, '/entry-pages'), query, { limit: 9 })
  }

  function getExternalLinkUrl(page) {
    return url.externalLinkForPage(site, page.name)
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
        defaultLabel: 'Unique entrances',
        width: 'w-36',
        meta: { plot: true }
      }),
      !hasConversionGoalFilter(query) &&
        metrics.createPercentage({ meta: { showOnHover: true } }),
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
      color="bg-orange-50 group-hover/row:bg-orange-100"
      onListUpdate={onListUpdate}
    />
  )
}

function ExitPages({ afterFetchData, onListUpdate }) {
  const site = useSiteContext()
  const { query } = useQueryContext()
  function fetchData() {
    return api.get(url.apiPath(site, '/exit-pages'), query, { limit: 9 })
  }

  function getExternalLinkUrl(page) {
    return url.externalLinkForPage(site, page.name)
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
        defaultLabel: 'Unique exits',
        width: 'w-36',
        meta: { plot: true }
      }),
      !hasConversionGoalFilter(query) &&
        metrics.createPercentage({ meta: { showOnHover: true } }),
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
      color="bg-orange-50 group-hover/row:bg-orange-100"
      onListUpdate={onListUpdate}
    />
  )
}

function TopPages({ afterFetchData, onListUpdate }) {
  const { query } = useQueryContext()
  const site = useSiteContext()
  function fetchData() {
    return api.get(url.apiPath(site, '/pages'), query, { limit: 9 })
  }

  function getExternalLinkUrl(page) {
    return url.externalLinkForPage(site, page.name)
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
      !hasConversionGoalFilter(query) &&
        metrics.createPercentage({ meta: { showOnHover: true } }),
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
      color="bg-orange-50 group-hover/row:bg-orange-100"
      onListUpdate={onListUpdate}
    />
  )
}

export default function Pages() {
  const { query } = useQueryContext()
  const site = useSiteContext()

  const tabKey = `pageTab__${site.domain}`
  const storedTab = storage.getItem(tabKey)
  const [mode, setMode] = useState(storedTab || 'pages')
  const [loading, setLoading] = useState(true)
  const [skipImportedReason, setSkipImportedReason] = useState(null)
  const { onListUpdate, listData, linkProps, listLoading, reset } =
    useMoreLinkData()

  function switchTab(mode) {
    storage.setItem(tabKey, mode)
    setMode(mode)
    reset()
  }

  function afterFetchData(apiResponse) {
    setLoading(false)
    setSkipImportedReason(apiResponse.skip_imported_reason)
  }

  useEffect(() => setLoading(true), [query, mode])
  useEffect(() => {
    reset()
  }, [query, mode, reset])

  function renderContent() {
    switch (mode) {
      case 'entry-pages':
        return (
          <EntryPages
            afterFetchData={afterFetchData}
            onListUpdate={onListUpdate}
          />
        )
      case 'exit-pages':
        return (
          <ExitPages
            afterFetchData={afterFetchData}
            onListUpdate={onListUpdate}
          />
        )
      case 'pages':
      default:
        return (
          <TopPages
            afterFetchData={afterFetchData}
            onListUpdate={onListUpdate}
          />
        )
    }
  }

  return (
    <ReportLayout className="overflow-x-hidden">
      <ReportHeader>
        <div className="flex gap-x-3">
          <TabWrapper>
            {[
              {
                label: hasConversionGoalFilter(query)
                  ? 'Conversion pages'
                  : 'Top pages',
                value: 'pages'
              },
              { label: 'Entry pages', value: 'entry-pages' },
              { label: 'Exit pages', value: 'exit-pages' }
            ].map(({ value, label }) => (
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
        <MoreLink
          list={listData}
          linkProps={linkProps}
          loading={listLoading}
          className=""
          onClick={undefined}
        />
      </ReportHeader>
      {renderContent()}
    </ReportLayout>
  )
}
