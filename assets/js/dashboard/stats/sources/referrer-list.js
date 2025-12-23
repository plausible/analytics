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
import { ReportLayout } from '../reports/report-layout'
import { ReportHeader } from '../reports/report-header'
import { TabButton, TabWrapper } from '../../components/tabs'
import MoreLink from '../more-link'

const NO_REFERRER = 'Direct / None'

export default function Referrers({ source }) {
  const { query } = useQueryContext()
  const site = useSiteContext()
  const [skipImportedReason, setSkipImportedReason] = useState(null)
  const [loading, setLoading] = useState(true)
  const [moreLinkVisible, setMoreLinkVisible] = useState(true)
  const [moreLinkClickable, setMoreLinkClickable] = useState(false)

  useEffect(() => {
    setLoading(true)
    setMoreLinkVisible(true)
    setMoreLinkClickable(false)
  }, [query])

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
    if (apiResponse.results && apiResponse.results.length > 0) {
      setMoreLinkClickable(true)
    } else {
      setMoreLinkVisible(false)
    }
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
    <ReportLayout className="overflow-x-hidden">
      <ReportHeader>
        <div className="flex gap-x-3">
          <TabWrapper>
            <TabButton active={true} onClick={() => {}}>
              Top referrers
            </TabButton>
          </TabWrapper>
          <ImportedQueryUnsupportedWarning
            loading={loading}
            skipImportedReason={skipImportedReason}
          />
        </div>
        <MoreLink
          visible={moreLinkVisible}
          clickable={moreLinkClickable}
          linkProps={{
            path: referrersDrilldownRoute.path,
            params: { referrer: url.maybeEncodeRouteParam(source) },
            search: (search) => search
          }}
        />
      </ReportHeader>
      <ListReport
        fetchData={fetchReferrers}
        afterFetchData={afterFetchReferrers}
        getFilterInfo={getFilterInfo}
        keyLabel="Referrer"
        metrics={chooseMetrics()}
        getExternalLinkUrl={getExternalLinkUrl}
        renderIcon={renderIcon}
        color="bg-blue-50"
      />
    </ReportLayout>
  )
}
