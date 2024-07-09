import React, { useCallback } from "react";
import { withRouter } from 'react-router-dom'

import Modal from './modal'
import withQueryContext from "../../components/query-context-hoc";
import { hasGoalFilter } from "../../util/filters";
import BreakdownModal from "./breakdown-modal";
import * as metrics from "../reports/metrics";
import { addFilter } from "../../query";

function ReferrerDrilldownModal(props) {
  const { site, query, match } = props

  const reportInfo = {
    title: "Referrer Drilldown",
    dimension: 'referrer',
    endpoint: `/referrers/${match.params.referrer}`,
    dimensionLabel: "Referrer"
  }

  const getFilterInfo = useCallback((listItem) => {
    return {
      prefix: reportInfo.dimension,
      filter: ['is', reportInfo.dimension, [listItem.name]]
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
      metrics.createBounceRate(),
      metrics.createVisitDuration()
    ]
  }

  const renderIcon = useCallback((listItem) => {
    return (
      <img
        src={`/favicon/sources/${encodeURIComponent(listItem.name)}`}
        className="h-4 w-4 mr-2 align-middle inline"
      />
    )
  }, [])

  const getExternalLinkURL = useCallback((listItem) => {
    if (listItem.name !== "Direct / None") {
      return '//' + listItem.name
    }
  }, [])

  return (
    <Modal site={site}>
      <BreakdownModal
        site={site}
        query={query}
        reportInfo={reportInfo}
        metrics={chooseMetrics()}
        getFilterInfo={getFilterInfo}
        addSearchFilter={addSearchFilter}
        renderIcon={renderIcon}
        getExternalLinkURL={getExternalLinkURL}
      />
    </Modal>
  )
}

export default withRouter(withQueryContext(ReferrerDrilldownModal))
