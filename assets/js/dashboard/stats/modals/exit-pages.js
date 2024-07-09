import React, {useCallback} from "react";
import { withRouter } from 'react-router-dom'
import Modal from './modal'
import { hasGoalFilter } from "../../util/filters";
import { addFilter } from '../../query'
import BreakdownModal from "./breakdown-modal";
import * as metrics from '../reports/metrics'
import withQueryContext from "../../components/query-context-hoc";

function ExitPagesModal(props) {
  const { site, query } = props

  const reportInfo = {
    title: 'Exit Pages',
    dimension: 'exit_page',
    endpoint: '/exit-pages',
    dimensionLabel: 'Page url'
  }

  const getFilterInfo = useCallback((listItem) => {
    return {
      prefix: reportInfo.dimension,
      filter: ["is", reportInfo.dimension, [listItem.name]]
    }
  }, [])

  const addSearchFilter = useCallback((query, searchString) => {
    return addFilter(query, ['contains', reportInfo.dimension, [searchString]])
  }, [])

  function chooseMetrics() {
    if (hasGoalFilter(query)) {
      return [
        metrics.createTotalVisitors(),
        metrics.createVisitors({renderLabel: (_query) => 'Conversions'}),
        metrics.createConversionRate()
      ]
    }

    if (query.period === 'realtime') {
      return [
        metrics.createVisitors({renderLabel: (_query) => 'Current visitors'})
      ]
    }
    
    return [
      metrics.createVisitors({renderLabel: (_query) => "Visitors" }),
      metrics.createVisits({renderLabel: (_query) => "Total Exits" }),
      metrics.createExitRate()
    ]
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

export default withRouter(withQueryContext(ExitPagesModal))
