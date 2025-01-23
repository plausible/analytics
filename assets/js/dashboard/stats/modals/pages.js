import React, {useCallback} from "react";
import Modal from './modal'
import { hasConversionGoalFilter, isRealTimeDashboard } from "../../util/filters";
import { addFilter } from '../../query'
import BreakdownModal from "./breakdown-modal";
import * as metrics from '../reports/metrics'
import * as url from '../../util/url';
import { useQueryContext } from "../../query-context";
import { useSiteContext } from "../../site-context";
import { SortDirection } from "../../hooks/use-order-by";

function PagesModal() {
  const { query } = useQueryContext();
  const site = useSiteContext();

  const reportInfo = {
    title: 'Top Pages',
    dimension: 'page',
    endpoint: url.apiPath(site, '/pages'),
    dimensionLabel: 'Page url',
    defaultOrder: ["visitors", SortDirection.desc]
  }

  const getFilterInfo = useCallback((listItem) => {
    return {
      prefix: reportInfo.dimension,
      filter: ["is", reportInfo.dimension, [listItem.name]]
    }
  }, [reportInfo.dimension])

  const addSearchFilter = useCallback((query, searchString) => {
    return addFilter(query, ['contains', reportInfo.dimension, [searchString], { case_sensitive: false }])
  }, [reportInfo.dimension])

  function chooseMetrics() {
    if (hasConversionGoalFilter(query)) {
      return [
        metrics.createTotalVisitors(),
        metrics.createVisitors({renderLabel: (_query) => 'Conversions', width: 'w-28'}),
        metrics.createConversionRate()
      ]
    }

    if (isRealTimeDashboard(query)) {
      return [
        metrics.createVisitors({renderLabel: (_query) => 'Current visitors', width: 'w-36'})
      ]
    }

    const defaultMetrics = [
      metrics.createVisitors({renderLabel: (_query) => "Visitors" }),
      metrics.createPageviews(),
      metrics.createBounceRate(),
      metrics.createTimeOnPage()
    ]

    return site.hasScrollDepthEnabled ? [...defaultMetrics, metrics.createScrollDepth()] : defaultMetrics
  }

  return (
    <Modal>
      <BreakdownModal
        reportInfo={reportInfo}
        metrics={chooseMetrics()}
        getFilterInfo={getFilterInfo}
        addSearchFilter={addSearchFilter}
      />
    </Modal>
  )
}

export default PagesModal
