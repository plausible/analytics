import React, { useCallback } from "react";
import { withRouter } from 'react-router-dom'

import Modal from './modal'
import withQueryContext from "../../components/query-context-hoc";
import { hasGoalFilter } from "../../util/filters";
import BreakdownModal from "./breakdown-modal";
import * as metrics from "../reports/metrics";

const VIEWS = {
  countries: {title: 'Top Countries', dimension: 'country', endpoint: '/countries', dimensionLabel: 'Country'},
  regions: {title: 'Top Regions', dimension: 'region', endpoint: '/regions', dimensionLabel: 'Region'},
  cities: {title: 'Top Cities', dimension: 'city', endpoint: '/cities', dimensionLabel: 'City'},
}

function LocationsModal(props) {
  const { site, query, location } = props

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
      currentView === 'countries' && metrics.createPercentage()
    ].filter(m => !!m)
  }
  
  let renderIcon

  if (currentView === 'countries') {
    renderIcon = useCallback((listItem) => <span className="mr-1">{listItem.flag}</span>)
  } else {
    renderIcon = useCallback((listItem) => <span className="mr-1">{listItem.country_flag}</span>)
  }

  return (
    <Modal site={site}>
      <BreakdownModal
        site={site}
        query={query}
        reportInfo={reportInfo}
        metrics={chooseMetrics()}
        getFilterInfo={getFilterInfo}
        renderIcon={renderIcon}
        searchEnabled={false}
      />
    </Modal>
  )
}

export default withRouter(withQueryContext(LocationsModal))
