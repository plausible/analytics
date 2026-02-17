import React, { useCallback } from 'react'
import Modal from './modal'
import {
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import BreakdownModal from './breakdown-modal'
import * as metrics from '../reports/metrics'
import * as url from '../../util/url'
import { addFilter, revenueAvailable } from '../../dashboard-state'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { SortDirection } from '../../hooks/use-order-by'
import { SourceFavicon } from '../sources/source-favicon'

const VIEWS = {
  sources: {
    info: {
      title: 'Top sources',
      dimension: 'source',
      endpoint: '/sources',
      dimensionLabel: 'Source',
      defaultOrder: ['visitors', SortDirection.desc]
    },
    renderIcon: (listItem) => {
      return (
        <SourceFavicon
          name={listItem.name}
          className="size-4 mr-2 align-middle inline"
        />
      )
    }
  },
  channels: {
    info: {
      title: 'Top acquisition channels',
      dimension: 'channel',
      endpoint: '/channels',
      dimensionLabel: 'Channel',
      defaultOrder: ['visitors', SortDirection.desc]
    }
  },
  utm_mediums: {
    info: {
      title: 'Top UTM mediums',
      dimension: 'utm_medium',
      endpoint: '/utm_mediums',
      dimensionLabel: 'UTM medium',
      defaultOrder: ['visitors', SortDirection.desc]
    }
  },
  utm_sources: {
    info: {
      title: 'Top UTM sources',
      dimension: 'utm_source',
      endpoint: '/utm_sources',
      dimensionLabel: 'UTM source',
      defaultOrder: ['visitors', SortDirection.desc]
    }
  },
  utm_campaigns: {
    info: {
      title: 'Top UTM campaigns',
      dimension: 'utm_campaign',
      endpoint: '/utm_campaigns',
      dimensionLabel: 'UTM campaign',
      defaultOrder: ['visitors', SortDirection.desc]
    }
  },
  utm_contents: {
    info: {
      title: 'Top UTM contents',
      dimension: 'utm_content',
      endpoint: '/utm_contents',
      dimensionLabel: 'UTM content',
      defaultOrder: ['visitors', SortDirection.desc]
    }
  },
  utm_terms: {
    info: {
      title: 'Top UTM terms',
      dimension: 'utm_term',
      endpoint: '/utm_terms',
      dimensionLabel: 'UTM term',
      defaultOrder: ['visitors', SortDirection.desc]
    }
  }
}

function SourcesModal({ currentView }) {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  /*global BUILD_EXTRA*/
  const showRevenueMetrics =
    BUILD_EXTRA && revenueAvailable(dashboardState, site)

  let reportInfo = VIEWS[currentView].info
  reportInfo = {
    ...reportInfo,
    endpoint: url.apiPath(site, reportInfo.endpoint)
  }

  const getFilterInfo = useCallback(
    (listItem) => {
      return {
        prefix: reportInfo.dimension,
        filter: ['is', reportInfo.dimension, [listItem.name]]
      }
    },
    [reportInfo.dimension]
  )

  const addSearchFilter = useCallback(
    (dashboardState, searchString) => {
      return addFilter(dashboardState, [
        'contains',
        reportInfo.dimension,
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
