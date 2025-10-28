import React, { useEffect, useState } from 'react'
import * as api from '../../api'
import * as url from '../../util/url'
import * as metrics from '../reports/metrics'
import { hasConversionGoalFilter } from '../../util/filters'
import ListReport from '../reports/list'
import ImportedQueryUnsupportedWarning from '../../stats/imported-query-unsupported-warning'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import { referrersDrilldownRoute } from '../../router'
import { SourceFavicon } from './source-favicon'

const NO_REFERRER = 'Direct / None'

export default function Referrers({ source }) {
  const { query } = useQueryContext()
  const site = useSiteContext()
  const [skipImportedReason, setSkipImportedReason] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => setLoading(true), [query])

  function fetchReferrers() {
    return api.get(
      url.apiPath(site, `/referrers/${encodeURIComponent(source)}`),
      query,
      { limit: 9 }
    )
  }

  function afterFetchReferrers(apiResponse) {
    setLoading(false)
    setSkipImportedReason(apiResponse.skip_imported_reason)
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
      hasConversionGoalFilter(query) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <div className="flex flex-col grow">
      <div className="flex gap-x-1">
        <h3 className="font-bold dark:text-gray-100">Top Referrers</h3>
        <ImportedQueryUnsupportedWarning
          loading={loading}
          skipImportedReason={skipImportedReason}
        />
      </div>
      <ListReport
        fetchData={fetchReferrers}
        afterFetchData={afterFetchReferrers}
        getFilterInfo={getFilterInfo}
        keyLabel="Referrer"
        metrics={chooseMetrics()}
        detailsLinkProps={{
          path: referrersDrilldownRoute.path,
          params: { referrer: url.maybeEncodeRouteParam(source) },
          search: (search) => search
        }}
        getExternalLinkUrl={getExternalLinkUrl}
        renderIcon={renderIcon}
        color="bg-blue-50"
      />
    </div>
  )
}
