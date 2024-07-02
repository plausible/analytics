import React, {useCallback} from "react";
import { withRouter } from 'react-router-dom'
import Modal from './modal'
import numberFormatter, { durationFormatter } from '../../util/number-formatter'
import { hasGoalFilter } from "../../util/filters";
import { parseQuery } from '../../query'
import BreakdownModal from "./breakdown-modal";

function EntryPagesModal(props) {
  const query = parseQuery(props.location.search, props.site)

  const reportInfo = {
    title: 'Entry Pages',
    dimension: 'entry_page',
    endpoint: '/entry-pages',
    dimensionLabel: 'Entry page'
  }

  const getFilterInfo = (listItem) => {
    return {
      prefix: reportInfo.dimension,
      filter: ["is", reportInfo.dimension, [listItem.name]]
    }
  }

  const getMetrics = useCallback((query) => {
    if (hasGoalFilter(query)) {
      return [
        {key: 'total_visitors', label: 'Total visitors', formatter: numberFormatter},
        {key: 'visitors', label: 'Conversions', formatter: numberFormatter},
        {key: 'conversion_rate', label: 'CR', formatter: numberFormatter}
      ]
    }

    if (query.period === 'realtime') {
      return [
        {key: 'visitors', label: "Current visitors", formatter: numberFormatter}
      ]
    }
    
    return [
      {key: 'visitors', label: "Visitors", formatter: numberFormatter},
      {key: 'visits', label: "Total Entrances", formatter: numberFormatter},
      {key: 'visit_duration', label: "Visit Duration", formatter: durationFormatter}
    ]
  }, [])

  return (
    <Modal site={props.site}>
      <BreakdownModal
        site={props.site}
        query={query}
        reportInfo={reportInfo}
        getMetrics={getMetrics}
        getFilterInfo={getFilterInfo}
      />
    </Modal>
  )
}

export default withRouter(EntryPagesModal)
