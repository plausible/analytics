import React from 'react'
import ListReport, { MIN_HEIGHT } from '../reports/list'
import * as metrics from '../reports/metrics'
import * as api from '../../api'
import * as url from '../../util/url'
import { EVENT_PROPS_PREFIX, hasConversionGoalFilter } from '../../util/filters'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import { customPropsRoute } from '../../router'

export default function Properties({ propKey, afterFetchData }) {
  const { query } = useQueryContext()
  const site = useSiteContext()

  function fetchProps() {
    return api.get(
      url.apiPath(site, `/custom-prop-values/${encodeURIComponent(propKey)}`),
      query
    )
  }

  /*global BUILD_EXTRA*/
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
      hasConversionGoalFilter(query) && metrics.createConversionRate(),
      !hasConversionGoalFilter(query) && metrics.createPercentage(),
      BUILD_EXTRA &&
        metrics.createTotalRevenue({ meta: { hiddenOnMobile: true } }),
      BUILD_EXTRA &&
        metrics.createAverageRevenue({ meta: { hiddenOnMobile: true } })
    ].filter((metric) => !!metric)
  }

  function renderBreakdown() {
    return (
      <ListReport
        fetchData={fetchProps}
        afterFetchData={afterFetchData}
        getFilterInfo={getFilterInfo}
        keyLabel={propKey}
        metrics={chooseMetrics()}
        detailsLinkProps={{
          path: customPropsRoute.path,
          params: { propKey },
          search: (search) => search
        }}
        color="bg-red-50 group-hover/row:bg-red-100"
        colMinWidth={90}
      />
    )
  }

  const getFilterInfo = (listItem) => ({
    prefix: `${EVENT_PROPS_PREFIX}${propKey}`,
    filter: ['is', `${EVENT_PROPS_PREFIX}${propKey}`, [listItem.name]]
  })

  if (!propKey) {
    return (
      <div className="font-medium text-gray-500 dark:text-gray-400 py-12 text-center">
        No custom properties found
      </div>
    )
  }

  return (
    <div className="w-full" style={{ minHeight: `${MIN_HEIGHT}px` }}>
      {renderBreakdown()}
    </div>
  )
}
