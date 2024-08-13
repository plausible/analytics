import React, { useCallback } from "react";

import Modal from "./modal";
import { hasGoalFilter } from "../../util/filters";
import BreakdownModal from "./breakdown-modal";
import * as metrics from "../reports/metrics";
import * as url from "../../util/url";
import { useQueryContext } from "../../query-context";
import { useSiteContext } from "../../site-context";
import { addFilter } from "../../query";

const VIEWS = {
  countries: { title: 'Top Countries', dimension: 'country', endpoint: '/countries', dimensionLabel: 'Country' },
  regions: { title: 'Top Regions', dimension: 'region', endpoint: '/regions', dimensionLabel: 'Region' },
  cities: { title: 'Top Cities', dimension: 'city', endpoint: '/cities', dimensionLabel: 'City' },
}

function LocationsModal({ currentView }) {
  const { query } = useQueryContext();
  const site = useSiteContext();

  let reportInfo = VIEWS[currentView]
  reportInfo = {...reportInfo, endpoint: url.apiPath(site, reportInfo.endpoint)}

  const getFilterInfo = useCallback((listItem) => {
    return {
      prefix: reportInfo.dimension,
      filter: ["is", reportInfo.dimension, [listItem.code]],
      labels: { [listItem.code]: listItem.name }
    }
  }, [reportInfo.dimension])

  const addSearchFilter = useCallback((query, searchString) => {
    return addFilter(query, ['contains', `${reportInfo.dimension}_name`, [searchString]])
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
        addSearchFilter={addSearchFilter}
      />
    </Modal>
  )
}

export default LocationsModal
