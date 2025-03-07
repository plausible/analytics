import React, { useCallback } from "react";
import Modal from './modal'
import { addFilter } from '../../query'
import BreakdownModal from "./breakdown-modal";
import * as metrics from '../reports/metrics'
import * as url from '../../util/url';
import { useSiteContext } from "../../site-context";
import { SortDirection } from "../../hooks/use-order-by";

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
    metrics.createVisits({
      renderLabel: (_query) => 'Total Entrances',
      width: 'w-36'
    }),
    metrics.createVisitDuration()
  ]
}

function EntryPagesModal() {
  const site = useSiteContext();

  const reportInfo = {
    title: 'Entry Pages',
    dimension: 'entry_page',
    endpoint: url.apiPath(site, '/entry-pages'),
    dimensionLabel: 'Entry page',
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

export default EntryPagesModal
