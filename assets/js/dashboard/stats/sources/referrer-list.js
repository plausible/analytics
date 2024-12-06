import React, { useEffect, useState } from 'react';
import * as api from '../../api';
import * as url from '../../util/url';
import * as metrics from '../reports/metrics';
import { hasGoalFilter } from "../../util/filters";
import ListReport from '../reports/list';
import ImportedQueryUnsupportedWarning from '../../stats/imported-query-unsupported-warning';
import { useQueryContext } from '../../query-context';
import { useSiteContext } from '../../site-context';
import { referrersDrilldownRoute } from '../../router';

const NO_REFERRER = 'Direct / None'

export default function Referrers({ source }) {
  const { query } = useQueryContext();
  const site = useSiteContext()
  const [skipImportedReason, setSkipImportedReason] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => setLoading(true), [query])

  function fetchReferrers() {
    return api.get(url.apiPath(site, `/referrers/${encodeURIComponent(source)}`), query, { limit: 9 })
  }

  function afterFetchReferrers(apiResponse) {
    setLoading(false)
    setSkipImportedReason(apiResponse.skip_imported_reason)
  }

  function externalLinkDest(referrer) {
    if (referrer.name === NO_REFERRER) { return null }
    return `https://${referrer.name}`
  }

  function getFilterFor(referrer) {
    if (referrer.name === NO_REFERRER) { return null }

    return {
      prefix: 'referrer',
      filter: ["is", "referrer", [referrer.name]]
    }
  }

  function renderIcon(listItem) {
    return (
      <img
        alt=""
        src={`/favicon/sources/${encodeURIComponent(listItem.name)}`}
        referrerPolicy="no-referrer"
        className="inline w-4 h-4 mr-2 -mt-px align-middle"
      />
    )
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      hasGoalFilter(query) && metrics.createConversionRate(),
    ].filter(metric => !!metric)
  }

  return (
    <div className="flex flex-col flex-grow">
      <div className="flex gap-x-1">
        <h3 className="font-bold dark:text-gray-100">Top Referrers</h3>
        <ImportedQueryUnsupportedWarning loading={loading} skipImportedReason={skipImportedReason} />
      </div>
      <ListReport
        fetchData={fetchReferrers}
        afterFetchData={afterFetchReferrers}
        getFilterFor={getFilterFor}
        keyLabel="Referrer"
        metrics={chooseMetrics()}
        detailsLinkProps={{ path: referrersDrilldownRoute.path, params: {referrer: url.maybeEncodeRouteParam(source)}, search: (search) => search }}
        externalLinkDest={externalLinkDest}
        renderIcon={renderIcon}
        color="bg-blue-50"
      />
    </div>
  )
}
