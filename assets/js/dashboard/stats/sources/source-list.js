import React, { useEffect, useState } from 'react'

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
import { DropdownTabButton, TabButton, TabWrapper } from '../../components/tabs'

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
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query, currentTab])

  function setTab(tab) {
    return () => {
      storage.setItem(tabKey, tab)
      setCurrentTab(tab)
    }
  }

  function onChannelClick() {
    setTab('all')()
  }

  function renderContent() {
    if (Object.keys(UTM_TAGS).includes(currentTab)) {
      return <UTMSources tab={currentTab} afterFetchData={afterFetchData} />
    }

    switch (currentTab) {
      case 'channels':
        return (
          <Channels onClick={onChannelClick} afterFetchData={afterFetchData} />
        )
      case 'all':
      default:
        return <AllSources afterFetchData={afterFetchData} />
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
        <TabWrapper>
          {[
            { value: 'channels', label: 'Channels' },
            { value: 'all', label: 'Sources' }
          ].map(({ value, label }) => (
            <TabButton
              key={value}
              onClick={setTab(value)}
              active={currentTab === value}
            >
              {label}
            </TabButton>
          ))}
          <DropdownTabButton
            className="md:relative"
            transitionClassName="md:left-auto md:w-56"
            active={Object.keys(UTM_TAGS).includes(currentTab)}
            options={Object.entries(UTM_TAGS).map(([value, { title }]) => ({
              value,
              label: title,
              onClick: setTab(value),
              selected: currentTab === value
            }))}
          >
            {UTM_TAGS[currentTab] ? UTM_TAGS[currentTab].title : 'Campaigns'}
          </DropdownTabButton>
        </TabWrapper>
      </div>
      {/* Main Contents */}
      {renderContent()}
    </div>
  )
}
