import React, { useCallback } from "react";
import { withRouter } from 'react-router-dom'

import Modal from './modal'
import { hasGoalFilter, isRealTimeDashboard } from "../../util/filters";
import BreakdownModal from "./breakdown-modal";
import * as metrics from "../reports/metrics";
import { addFilter } from "../../query";
import { useQueryContext } from "../../query-context";

const VIEWS = {
  sources: {
    info: { title: 'Top Sources', dimension: 'source', endpoint: '/sources', dimensionLabel: 'Source' },
    renderIcon: (listItem) => {
      return (
        <img
          src={`/favicon/sources/${encodeURIComponent(listItem.name)}`}
          className="h-4 w-4 mr-2 align-middle inline"
        />
      )
    }
  },
  utm_mediums: {
    info: { title: 'Top UTM Mediums', dimension: 'utm_medium', endpoint: '/utm_mediums', dimensionLabel: 'UTM Medium' }
  },
  utm_sources: {
    info: { title: 'Top UTM Sources', dimension: 'utm_source', endpoint: '/utm_sources', dimensionLabel: 'UTM Source' }
  },
  utm_campaigns: {
    info: { title: 'Top UTM Campaigns', dimension: 'utm_campaign', endpoint: '/utm_campaigns', dimensionLabel: 'UTM Campaign' }
  },
  utm_contents: {
    info: { title: 'Top UTM Contents', dimension: 'utm_content', endpoint: '/utm_contents', dimensionLabel: 'UTM Content' }
  },
  utm_terms: {
    info: { title: 'Top UTM Terms', dimension: 'utm_term', endpoint: '/utm_terms', dimensionLabel: 'UTM Term' }
  },
}

function SourcesModal({ location }) {
  const { query } = useQueryContext();

  const urlParts = location.pathname.split('/')
  const currentView = urlParts[urlParts.length - 1]

  const reportInfo = VIEWS[currentView].info

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
      metrics.createBounceRate(),
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
        renderIcon={VIEWS[currentView].renderIcon}
      />
    </Modal>
  )
}

export default withRouter(SourcesModal)
