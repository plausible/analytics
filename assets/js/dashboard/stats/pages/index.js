import React, { useEffect, useState } from 'react'

import * as storage from '../../util/storage'
import ImportedQueryUnsupportedWarning from '../imported-query-unsupported-warning'
import { hasConversionGoalFilter } from '../../util/filters'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { entryPagesRoute, exitPagesRoute, topPagesRoute } from '../../router'
import { ReportLayout } from '../reports/report-layout'
import { ReportHeader } from '../reports/report-header'
import { TabButton, TabWrapper } from '../../components/tabs'
import MoreLink from '../more-link'
import { MoreLinkState } from '../more-link-state'
import { PagesIndex } from './pages'
import { EntryPagesIndex } from './entry-pages'
import { ExitPagesIndex } from './exit-pages'

export default function Pages() {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  const tabKey = `pageTab__${site.domain}`
  const storedTab = storage.getItem(tabKey)
  const [mode, setMode] = useState(storedTab || 'pages')
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
      case 'entry-pages':
        return {
          path: entryPagesRoute.path,
          search: (search) => search
        }
      case 'exit-pages':
        return {
          path: exitPagesRoute.path,
          search: (search) => search
        }
      case 'pages':
      default:
        return {
          path: topPagesRoute.path,
          search: (search) => search
        }
    }
  }

  function renderContent() {
    switch (mode) {
      case 'entry-pages':
        return <EntryPagesIndex afterFetchData={afterFetchData} />
      case 'exit-pages':
        return <ExitPagesIndex afterFetchData={afterFetchData} />
      case 'pages':
      default:
        return <PagesIndex afterFetchData={afterFetchData} />
    }
  }

  return (
    <ReportLayout testId="report-pages" className="overflow-x-hidden">
      <ReportHeader>
        <div className="flex gap-x-3">
          <TabWrapper>
            {[
              {
                label: hasConversionGoalFilter(dashboardState)
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
        <MoreLink state={moreLinkState} linkProps={moreLinkProps()} />
      </ReportHeader>
      {renderContent()}
    </ReportLayout>
  )
}
