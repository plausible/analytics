import React, { useCallback } from 'react'

import Modal from './modal'
import {
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import BreakdownModal from './breakdown-modal'
import * as metrics from '../reports/metrics'
import * as url from '../../util/url'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { addFilter, revenueAvailable } from '../../dashboard-state'
import { SortDirection } from '../../hooks/use-order-by'

const VIEWS = {
  countries: {
    title: 'Top countries',
    dimension: 'country',
    endpoint: '/countries',
    dimensionLabel: 'Country',
    defaultOrder: ['visitors', SortDirection.desc]
  },
  regions: {
    title: 'Top regions',
    dimension: 'region',
    endpoint: '/regions',
    dimensionLabel: 'Region',
    defaultOrder: ['visitors', SortDirection.desc]
  },
  cities: {
    title: 'Top cities',
    dimension: 'city',
    endpoint: '/cities',
    dimensionLabel: 'City',
    defaultOrder: ['visitors', SortDirection.desc]
  }
}

function LocationsModal({ currentView }) {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  /*global BUILD_EXTRA*/
  const showRevenueMetrics =
    BUILD_EXTRA && revenueAvailable(dashboardState, site)

  let reportInfo = VIEWS[currentView]
  reportInfo = {
    ...reportInfo,
    endpoint: url.apiPath(site, reportInfo.endpoint)
  }

  const getFilterInfo = useCallback(
    (listItem) => {
      return {
        prefix: reportInfo.dimension,
        filter: ['is', reportInfo.dimension, [listItem.code]],
        labels: { [listItem.code]: listItem.name }
      }
    },
    [reportInfo.dimension]
  )

  const addSearchFilter = useCallback(
    (dashboardState, searchString) => {
      return addFilter(dashboardState, [
        'contains',
        `${reportInfo.dimension}_name`,
        [searchString],
        { case_sensitive: false }
      ])
    },
    [reportInfo.dimension]
  )

  function chooseMetrics() {
    if (hasConversionGoalFilter(dashboardState)) {
      return [
        metrics.createTotalVisitors(),
        metrics.createVisitors({
          renderLabel: (_dashboardState) => 'Conversions',
          width: 'w-28'
        }),
        metrics.createConversionRate(),
        showRevenueMetrics && metrics.createTotalRevenue(),
        showRevenueMetrics && metrics.createAverageRevenue()
      ].filter((metric) => !!metric)
    }

    if (
      isRealTimeDashboard(dashboardState) &&
      !hasConversionGoalFilter(dashboardState)
    ) {
      return [
        metrics.createVisitors({
          renderLabel: (_dashboardState) => 'Current visitors',
          width: 'w-32'
        })
      ]
    }

    return [
      metrics.createVisitors({ renderLabel: (_dashboardState) => 'Visitors' }),
      currentView === 'countries' && metrics.createPercentage()
    ].filter((metric) => !!metric)
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
