import React, { useState } from 'react';
import * as api from '../../api'
import * as url from '../../util/url'
import { VISITORS_METRIC, maybeWithCR } from '../reports/metrics'
import ListReport from '../reports/list'
import ImportedQueryUnsupportedWarning from '../../stats/imported-query-unsupported-warning'

export default function Referrers({source, site, query}) {
  const [skipImportedReason, setSkipImportedReason] = useState(null)

  function fetchReferrers() {
    return api.get(url.apiPath(site, `/referrers/${encodeURIComponent(source)}`), query, {limit: 9})
  }

  function afterFetchReferrers(apiResponse) {
    setSkipImportedReason(apiResponse.skip_imported_reason)
  }

  function externalLinkDest(referrer) {
    if (referrer.name === 'Direct / None') { return null }
    return `https://${referrer.name}`
  }

  function getFilterFor(referrer) {
    if (referrer.name === 'Direct / None') { return null }

    return {
      prefix: 'referrer',
      filter: ["is", "referrer", [referrer.name]]
    }
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
      <div className="flex gap-x-1">
        <h3 className="font-bold dark:text-gray-100">Top Referrers</h3>
        <ImportedQueryUnsupportedWarning query={query} skipImportedReason={skipImportedReason}/>
      </div>
      <ListReport
        fetchData={fetchReferrers}
        afterFetchData={afterFetchReferrers}
        getFilterFor={getFilterFor}
        keyLabel="Referrer"
        metrics={maybeWithCR([VISITORS_METRIC], query)}
        detailsLink={url.sitePath(site, `/referrers/${encodeURIComponent(source)}`)}
        query={query}
        externalLinkDest={externalLinkDest}
        renderIcon={renderIcon}
        color="bg-blue-50"
      />
    </div>
  )
}
