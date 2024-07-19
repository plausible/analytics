import React, { useCallback } from "react";
import Modal from './modal'
import { hasGoalFilter, isRealTimeDashboard } from "../../util/filters";
import { addFilter } from '../../query'
import BreakdownModal from "./breakdown-modal";
import * as metrics from '../reports/metrics'
import { useQueryContext } from "../../query-context";

function EntryPagesModal() {
  const { query } = useQueryContext();

  const reportInfo = {
    title: 'Entry Pages',
    dimension: 'entry_page',
    endpoint: '/entry-pages',
    dimensionLabel: 'Entry page'
  }

  const getFilterInfo = useCallback((listItem) => {
    return {
      prefix: reportInfo.dimension,
      filter: ["is", reportInfo.dimension, [listItem.name]]
    }
  }, [reportInfo.dimension])

  const addSearchFilter = useCallback((query, searchString) => {
    return addFilter(query, ['contains', reportInfo.dimension, [searchString]])
  }, [reportInfo.dimension])

  function chooseMetrics() {
    if (hasGoalFilter(query)) {
      return [
        metrics.createTotalVisitors(),
        metrics.createVisitors({ renderLabel: (_query) => 'Conversions' }),
        metrics.createConversionRate()
      ]
    }

    if (isRealTimeDashboard(query)) {
      return [
        metrics.createVisitors({ renderLabel: (_query) => 'Current visitors' })
      ]
    }

    return [
      metrics.createVisitors({ renderLabel: (_query) => "Visitors" }),
      metrics.createVisits({ renderLabel: (_query) => "Total Entrances" }),
      metrics.createVisitDuration()
    ]
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

export default EntryPagesModal
