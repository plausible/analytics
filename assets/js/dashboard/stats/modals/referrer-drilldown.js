import React, { useCallback } from 'react'
import { useParams } from 'react-router-dom';

import Modal from './modal'
import BreakdownModal from "./breakdown-modal";
import * as metrics from "../reports/metrics";
import * as url from "../../util/url";
import { addFilter } from "../../query";
import { useSiteContext } from "../../site-context";
import { SortDirection } from '../../hooks/use-order-by';

function chooseMetrics({ situation }) {
  if (situation.is_filtering_on_goal) {
    return [
      metrics.createTotalVisitors(),
      metrics.createVisitors({
        renderLabel: (_query) => 'Conversions',
        width: 'w-28'
      }),
      metrics.createConversionRate()
    ]
  }

  if (situation.is_realtime_period) {
    return [
      metrics.createVisitors({
        renderLabel: (_query) => 'Current visitors',
        width: 'w-36'
      })
    ]
  }

  return [
    metrics.createVisitors({ renderLabel: (_query) => 'Visitors' }),
    metrics.createBounceRate(),
    metrics.createVisitDuration()
  ]
}

function ReferrerDrilldownModal() {
  const { referrer } = useParams();
  const site = useSiteContext();

  const reportInfo = {
    title: "Referrer Drilldown",
    dimension: 'referrer',
    endpoint: url.apiPath(site, `/referrers/${url.maybeEncodeRouteParam(referrer)}`
  ),
    dimensionLabel: "Referrer",
    defaultOrder: ["visitors", SortDirection.desc]
  }

  const getFilterInfo = useCallback((listItem) => {
    return {
      prefix: reportInfo.dimension,
      filter: ['is', reportInfo.dimension, [listItem.name]]
    }
  }, [reportInfo.dimension])

  const addSearchFilter = useCallback((query, searchString) => {
    return addFilter(query, ['contains', reportInfo.dimension, [searchString], { case_sensitive: false }])
  }, [reportInfo.dimension])

  const renderIcon = useCallback((listItem) => {
    return (
      <img
        alt=""
        src={`/favicon/sources/${encodeURIComponent(listItem.name)}`}
        className="h-4 w-4 mr-2 align-middle inline"
      />
    )
  }, [])

  const getExternalLinkURL = useCallback((listItem) => {
    if (listItem.name !== "Direct / None") {
      return '//' + listItem.name
    }
  }, [])

  return (
    <Modal>
      <BreakdownModal
        reportInfo={reportInfo}
        getMetrics={chooseMetrics}
        getFilterInfo={getFilterInfo}
        addSearchFilter={addSearchFilter}
        renderIcon={renderIcon}
        getExternalLinkURL={getExternalLinkURL}
      />
    </Modal>
  )
}

export default ReferrerDrilldownModal
