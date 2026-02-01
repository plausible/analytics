import React, { useCallback } from 'react'
import Modal from './../modal'
import BreakdownModal from './../breakdown-modal'
import * as url from '../../../util/url'
import { useDashboardStateContext } from '../../../dashboard-state-context'
import { useSiteContext } from '../../../site-context'
import { screenSizeIconFor } from '../../devices'
import chooseMetrics from './choose-metrics'
import { SortDirection } from '../../../hooks/use-order-by'

function ScreenSizesModal() {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  const reportInfo = {
    title: 'Devices',
    dimension: 'screen',
    endpoint: url.apiPath(site, '/screen-sizes'),
    dimensionLabel: 'Device',
    defaultOrder: ['visitors', SortDirection.desc]
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

  const renderIcon = useCallback(
    (listItem) => screenSizeIconFor(listItem.name),
    []
  )

  return (
    <Modal>
      <BreakdownModal
        reportInfo={reportInfo}
        metrics={chooseMetrics(dashboardState, site)}
        getFilterInfo={getFilterInfo}
        searchEnabled={false}
        renderIcon={renderIcon}
      />
    </Modal>
  )
}

export default ScreenSizesModal
