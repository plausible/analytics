import React, {useCallback} from "react";
import Modal from './modal'
import { addFilter } from '../../query'
import BreakdownModal from "./breakdown-modal";
import * as metrics from '../reports/metrics'
import * as url from '../../util/url';
import { useSiteContext } from "../../site-context";
import { SortDirection } from "../../hooks/use-order-by";

function chooseMetrics({ site, situation }) {
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

  const defaultMetrics = [
    metrics.createVisitors({ renderLabel: (_query) => 'Visitors' }),
    metrics.createPageviews(),
    metrics.createBounceRate(),
    metrics.createTimeOnPage()
  ]

  return site.scrollDepthVisible
    ? [...defaultMetrics, metrics.createScrollDepth()]
    : defaultMetrics
}

function PagesModal() {
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

  return (
    <Modal>
      <BreakdownModal
        reportInfo={reportInfo}
        getMetrics={chooseMetrics}
        getFilterInfo={getFilterInfo}
        addSearchFilter={addSearchFilter}
      />
    </Modal>
  )
}

export default PagesModal
