import React, { useCallback } from "react";
import { withRouter } from 'react-router-dom'

import Modal from './modal'
import { hasGoalFilter } from "../../util/filters";
import BreakdownModal from "./breakdown-modal";
import * as metrics from "../reports/metrics";
import { useQueryContext } from "../../query-context";

const VIEWS = {
  countries: { title: 'Top Countries', dimension: 'country', endpoint: '/countries', dimensionLabel: 'Country' },
  regions: { title: 'Top Regions', dimension: 'region', endpoint: '/regions', dimensionLabel: 'Region' },
  cities: { title: 'Top Cities', dimension: 'city', endpoint: '/cities', dimensionLabel: 'City' },
}

function LocationsModal({ location }) {
  const { query } = useQueryContext();

  const urlParts = location.pathname.split('/')
  const currentView = urlParts[urlParts.length - 1]

  const reportInfo = VIEWS[currentView]

  const getFilterInfo = useCallback((listItem) => {
    return {
      prefix: reportInfo.dimension,
      filter: ["is", reportInfo.dimension, [listItem.code]]
    }
  }, [])

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
      metrics.createVisitors({ renderLabel: (_query) => "Visitors" }),
      currentView === 'countries' && metrics.createPercentage()
    ].filter(metric => !!metric)
  }

  const renderIcon = useCallback((listItem) => {
    return (
      <span className="mr-1">{listItem.country_flag || listItem.flag}</span>
    )
  }, [])

  return (
    <Modal>
      <BreakdownModal
        reportInfo={reportInfo}
        metrics={chooseMetrics()}
        getFilterInfo={getFilterInfo}
        renderIcon={renderIcon}
        searchEnabled={false}
      />
    </Modal>
  )
}

export default withRouter(LocationsModal)
