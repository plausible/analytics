import React from 'react';
import * as api from '../../api'
import * as url from '../../util/url'
import { VISITORS_METRIC, maybeWithCR } from '../reports/metrics'
import ListReport from '../reports/list'

export default function Referrers({site, query}) {
  function fetchReferrers() {
    return api.get(url.apiPath(site, `/referrers/${encodeURIComponent(query.filters.source)}`), query, {limit: 9})
  }

  function externalLinkDest(referrer) {
    if (referrer.name === 'Direct / None') { return null }
    return `https://${referrer.name}`
  }

  function getFilterFor(referrer) {
    if (referrer.name === 'Direct / None') { return null }
    return { referrer: referrer.name }
  }

  function renderIcon(listItem) {
    return (
      <img
        src={`/favicon/sources/${encodeURIComponent(listItem.name)}`}
        referrerPolicy="no-referrer"
        className="inline w-4 h-4 mr-2 -mt-px align-middle"
      />
    )
  }

  return (
    <div className="flex flex-col flex-grow">
      <h3 className="font-bold dark:text-gray-100">Top Referrers</h3>
      <ListReport
        fetchData={fetchReferrers}
        getFilterFor={getFilterFor}
        keyLabel="Referrer"
        metrics={maybeWithCR([VISITORS_METRIC], query)}
        detailsLink={url.sitePath(site, `/referrers/${encodeURIComponent(query.filters.source)}`)}
        query={query}
        externalLinkDest={externalLinkDest}
        renderIcon={renderIcon}
        color="bg-blue-50"
      />
    </div>
  )
}
