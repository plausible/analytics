import React, { useCallback, useState } from "react";
import { withRouter } from 'react-router-dom'

import Modal from './modal'
import withQueryContext from "../../components/query-context-hoc";
import BreakdownModal from "./breakdown-modal";
import * as metrics from "../reports/metrics";


/*global BUILD_EXTRA*/
function ConversionsModal(props) {
  const { site, query } = props
  const [showRevenue, setShowRevenue] = useState(false)

  const reportInfo = {
    title: 'Goal Conversions',
    dimension: 'goal',
    endpoint: '/conversions',
    dimensionLabel: "Goal"
  }

  const getFilterInfo = useCallback((listItem) => {
    return {
      prefix: reportInfo.dimension,
      filter: ["is", reportInfo.dimension, [listItem.name]]
    }
  }, [])

  function chooseMetrics() {
    return [
      metrics.createVisitors({renderLabel: (_query) => "Uniques"}),
      metrics.createEvents({renderLabel: (_query) => "Total"}),
      metrics.createConversionRate(),
      showRevenue && metrics.createAverageRevenue(),
      showRevenue && metrics.createTotalRevenue(),
    ].filter(m => !!m)
  }

  // After a successful API response, we want to scan the rows of the
  // response and update the internal `showRevenue` state, which decides
  // whether revenue metrics are passed into BreakdownModal in `metrics`.
  const afterFetchData = useCallback((res) => {
    setShowRevenue(revenueInResponse(res))
  }, [showRevenue])

  // After fetching the next page, we never want to set `showRevenue` to
  // `false` as revenue metrics might exist in previously loaded data.
  const afterFetchNextPage = useCallback((res) => {
    if (!showRevenue && revenueInResponse(res)) { setShowRevenue(true) }
  }, [showRevenue])

  function revenueInResponse(apiResponse) {
    return apiResponse.results.some((item) => item.total_revenue)
  }

  return (
    <Modal site={site}>
      <BreakdownModal
        site={site}
        query={query}
        reportInfo={reportInfo}
        metrics={chooseMetrics()}
        afterFetchData={BUILD_EXTRA ? afterFetchData : undefined}
        afterFetchNextPage={BUILD_EXTRA ? afterFetchNextPage : undefined}
        getFilterInfo={getFilterInfo}
        searchEnabled={false}
      />
    </Modal>
  )
}

export default withRouter(withQueryContext(ConversionsModal))
