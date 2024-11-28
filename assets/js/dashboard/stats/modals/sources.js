import React, { useCallback } from "react";
import Modal from './modal'
import { hasGoalFilter, isRealTimeDashboard } from "../../util/filters";
import BreakdownModal from "./breakdown-modal";
import * as metrics from "../reports/metrics";
import * as url from "../../util/url";
import { addFilter } from "../../query";
import { useQueryContext } from "../../query-context";
import { useSiteContext } from "../../site-context";
import { SortDirection } from "../../hooks/use-order-by";

const VIEWS = {
  sources: {
    info: { title: 'Top Sources', dimension: 'source', endpoint: '/sources', dimensionLabel: 'Source', defaultOrder: ["visitors", SortDirection.desc] },
    renderIcon: (listItem) => {
      return (
        <img
          alt=""
          src={`/favicon/sources/${encodeURIComponent(listItem.name)}`}
          className="h-4 w-4 mr-2 align-middle inline"
        />
      )
    }
  },
  channels: {
    info: { title: 'Top Acquisition Channels', dimension: 'channel', endpoint: '/channels', dimensionLabel: 'Channel', defaultOrder: ["visitors", SortDirection.desc] }
  },
  utm_mediums: {
    info: { title: 'Top UTM Mediums', dimension: 'utm_medium', endpoint: '/utm_mediums', dimensionLabel: 'UTM Medium', defaultOrder: ["visitors", SortDirection.desc] }
  },
  utm_sources: {
    info: { title: 'Top UTM Sources', dimension: 'utm_source', endpoint: '/utm_sources', dimensionLabel: 'UTM Source', defaultOrder: ["visitors", SortDirection.desc] }
  },
  utm_campaigns: {
    info: { title: 'Top UTM Campaigns', dimension: 'utm_campaign', endpoint: '/utm_campaigns', dimensionLabel: 'UTM Campaign', defaultOrder: ["visitors", SortDirection.desc] }
  },
  utm_contents: {
    info: { title: 'Top UTM Contents', dimension: 'utm_content', endpoint: '/utm_contents', dimensionLabel: 'UTM Content', defaultOrder: ["visitors", SortDirection.desc] }
  },
  utm_terms: {
    info: { title: 'Top UTM Terms', dimension: 'utm_term', endpoint: '/utm_terms', dimensionLabel: 'UTM Term', defaultOrder: ["visitors", SortDirection.desc] }
  },
}

function SourcesModal({ currentView }) {
  const { query } = useQueryContext();
  const site = useSiteContext();

  let reportInfo = VIEWS[currentView].info
  reportInfo = {...reportInfo, endpoint: url.apiPath(site, reportInfo.endpoint)}

  const getFilterInfo = useCallback((listItem) => {
    return {
      prefix: reportInfo.dimension,
      filter: ["is", reportInfo.dimension, [listItem.name]]
    }
  }, [reportInfo.dimension])

  const addSearchFilter = useCallback((query, searchString) => {
    return addFilter(query, ['contains', reportInfo.dimension, [searchString], { case_sensitive: false }])
  }, [reportInfo.dimension])

  function chooseMetrics() {
    if (hasGoalFilter(query)) {
      return [
        metrics.createTotalVisitors(),
        metrics.createVisitors({ renderLabel: (_query) => 'Conversions', width: 'w-28' }),
        metrics.createConversionRate()
      ]
    }

    if (isRealTimeDashboard(query)) {
      return [
        metrics.createVisitors({ renderLabel: (_query) => 'Current visitors', width: 'w-36' })
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

export default SourcesModal
