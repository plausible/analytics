import React, { useCallback } from "react";
import { withRouter } from 'react-router-dom'

import Modal from './modal'
import withQueryContext from "../../components/query-context-hoc";
import { addFilter } from '../../query'
import { specialTitleWhenGoalFilter } from "../behaviours/goal-conversions";
import { EVENT_PROPS_PREFIX, hasGoalFilter } from "../../util/filters"
import BreakdownModal from "./breakdown-modal";
import * as metrics from "../reports/metrics";

function PropsModal(props) {
  const {site, query, location, revenueAvailable} = props
  const propKey = location.pathname.split('/').filter(i => i).pop()

  /*global BUILD_EXTRA*/
  const showRevenueMetrics = BUILD_EXTRA && revenueAvailable

  const reportInfo = {
    title: specialTitleWhenGoalFilter(query, 'Custom Property Breakdown'),
    dimension: propKey,
    endpoint: `/custom-prop-values/${propKey}`,
    dimensionLabel: propKey
  }

  const getFilterInfo = useCallback((listItem) => {
    return {
      prefix: `${EVENT_PROPS_PREFIX}${propKey}`,
      filter: ["is", `${EVENT_PROPS_PREFIX}${propKey}`, [listItem.name]]
    }
  }, [])

  const addSearchFilter = useCallback((query, s) => {
    return addFilter(query, ['contains', `${EVENT_PROPS_PREFIX}${propKey}`, [s]])
  }, [])

  function chooseMetrics() {
    return [
      metrics.createVisitors({renderLabel: (_query) => "Visitors"}),
      metrics.createEvents({renderLabel: (_query) => "Events"}),
      hasGoalFilter(query) && metrics.createConversionRate(),
      !hasGoalFilter(query) && metrics.createPercentage(),
      showRevenueMetrics && metrics.createAverageRevenue(),
      showRevenueMetrics && metrics.createTotalRevenue(),
    ].filter(m => !!m)
  }

  return (
    <Modal site={site}>
      <BreakdownModal
        site={site}
        query={query}
        reportInfo={reportInfo}
        metrics={chooseMetrics()}
        getFilterInfo={getFilterInfo}
        addSearchFilter={addSearchFilter}
      />
    </Modal>
  )
}

export default withRouter(withQueryContext(PropsModal))
