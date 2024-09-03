import React, { useCallback } from "react";
import Modal from './modal'
import { hasGoalFilter } from "../../util/filters";
import { addFilter } from '../../query'
import BreakdownModal from "./breakdown-modal";
import * as metrics from '../reports/metrics'
import * as url from '../../util/url';
import { useQueryContext } from "../../query-context";
import { useSiteContext } from "../../site-context";

function ExitPagesModal() {
  const { query } = useQueryContext();
  const site = useSiteContext();

  const reportInfo = {
    title: 'Exit Pages',
    dimension: 'exit_page',
    endpoint: url.apiPath(site, '/exit-pages'),
    dimensionLabel: 'Page url'
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

    if (query.period === 'realtime') {
      return [
        metrics.createVisitors({ renderLabel: (_query) => 'Current visitors' })
      ]
    }

    return [
      metrics.createVisitors({ renderLabel: (_query) => "Visitors", sortable: false }),
      metrics.createVisits({ renderLabel: (_query) => "Total Exits", sortable: false }),
      metrics.createExitRate()
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

export default ExitPagesModal
