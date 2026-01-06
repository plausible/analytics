import React from 'react'
import ListReport from '../reports/list'
import * as metrics from '../reports/metrics'
import * as url from '../../util/url'
import * as api from '../../api'
import { EVENT_PROPS_PREFIX } from '../../util/filters'
import { useSiteContext } from '../../site-context'
import { useQueryContext } from '../../query-context'

export function SpecialGoalPropBreakdown({ prop, afterFetchData }) {
  const site = useSiteContext()
  const { query } = useQueryContext()

  function fetchData() {
    return api.get(url.apiPath(site, `/custom-prop-values/${prop}`), query)
  }

  function getExternalLinkUrlFactory() {
    if (prop === 'path') {
      return (listItem) => url.externalLinkForPage(site, listItem.name)
    } else if (prop === 'search_query') {
      return null // WP Search Queries should not become external links
    } else {
      return (listItem) => listItem.name
    }
  }

  function getFilterInfo(listItem) {
    return {
      prefix: EVENT_PROPS_PREFIX,
      filter: ['is', `${EVENT_PROPS_PREFIX}${prop}`, [listItem['name']]]
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({
        renderLabel: (_query) => 'Visitors',
        meta: { plot: true }
      }),
      metrics.createEvents({
        renderLabel: (_query) => 'Events',
        meta: { hiddenOnMobile: true }
      }),
      metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel={prop}
      metrics={chooseMetrics()}
      getExternalLinkUrl={getExternalLinkUrlFactory()}
      color="bg-red-50"
      colMinWidth={90}
    />
  )
}
