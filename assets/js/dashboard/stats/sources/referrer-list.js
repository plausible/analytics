import React from 'react'
import * as api from '../../api'
import * as url from '../../util/url'
import * as metrics from '../reports/metrics'
import { hasConversionGoalFilter } from '../../util/filters'
import ListReport from '../reports/list'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { SourceFavicon } from './source-favicon'

const NO_REFERRER = 'Direct / None'

export default function Referrers({ source, afterFetchData }) {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  function fetchReferrers() {
    return api.get(
      url.apiPath(site, `/referrers/${encodeURIComponent(source)}`),
      dashboardState,
      { limit: 9 }
    )
  }

  function getExternalLinkUrl(referrer) {
    if (referrer.name === NO_REFERRER) {
      return null
    }
    return `https://${referrer.name}`
  }

  function getFilterInfo(referrer) {
    if (referrer.name === NO_REFERRER) {
      return null
    }

    return {
      prefix: 'referrer',
      filter: ['is', 'referrer', [referrer.name]]
    }
  }

  function renderIcon(listItem) {
    return (
      <SourceFavicon
        name={listItem.name}
        className="inline size-4 mr-2 -mt-px align-middle"
      />
    )
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      hasConversionGoalFilter(dashboardState) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchReferrers}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel="Referrer"
      metrics={chooseMetrics()}
      getExternalLinkUrl={getExternalLinkUrl}
      renderIcon={renderIcon}
      color="bg-blue-50"
    />
  )
}
