import React, { useCallback } from "react";
import { useParams } from "react-router-dom";

import Modal from './modal'
import { addFilter, revenueAvailable } from '../../query'
import { specialTitleWhenGoalFilter } from "../behaviours/goal-conversions";
import { EVENT_PROPS_PREFIX } from "../../util/filters"
import BreakdownModal from "./breakdown-modal";
import * as metrics from "../reports/metrics";
import * as url from "../../util/url";
import { useQueryContext } from "../../query-context";
import { useSiteContext } from "../../site-context";
import { SortDirection } from "../../hooks/use-order-by";

function chooseMetricsFactory(showRevenueMetrics) {
  return function chooseMetrics({situation}) {
  return [
    metrics.createVisitors({ renderLabel: (_query) => "Visitors" }),
    metrics.createEvents({ renderLabel: (_query) => "Events" }),
    situation.is_filtering_on_goal && metrics.createConversionRate(),
    !situation.is_filtering_on_goal && metrics.createPercentage(),
    showRevenueMetrics && metrics.createAverageRevenue(),
    showRevenueMetrics && metrics.createTotalRevenue(),
  ].filter(metric => !!metric)}
}

function PropsModal() {
  const { query } = useQueryContext();
  const site = useSiteContext();
  const { propKey } = useParams();

  /*global BUILD_EXTRA*/
  const showRevenueMetrics = BUILD_EXTRA && revenueAvailable(query, site)

  const reportInfo = {
    title: specialTitleWhenGoalFilter(query, 'Custom Property Breakdown'),
    dimension: propKey,
    endpoint: url.apiPath(site, `/custom-prop-values/${url.maybeEncodeRouteParam(propKey)}`),
    dimensionLabel: propKey,
    defaultOrder: ["visitors", SortDirection.desc]
  }

  const getFilterInfo = useCallback((listItem) => {
    return {
      prefix: `${EVENT_PROPS_PREFIX}${propKey}`,
      filter: ["is", `${EVENT_PROPS_PREFIX}${propKey}`, [listItem.name]]
    }
  }, [propKey])

  const addSearchFilter = useCallback((query, searchString) => {
    return addFilter(query, ['contains', `${EVENT_PROPS_PREFIX}${propKey}`, [searchString], { case_sensitive: false }])
  }, [propKey])


  return (
    <Modal>
      <BreakdownModal
        reportInfo={reportInfo}
        getMetrics={chooseMetricsFactory(showRevenueMetrics)}
        getFilterInfo={getFilterInfo}
        addSearchFilter={addSearchFilter}
      />
    </Modal>
  )
}

export default PropsModal
