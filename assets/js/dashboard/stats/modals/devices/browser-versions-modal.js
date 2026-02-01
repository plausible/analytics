import React, { useCallback } from 'react'
import Modal from './../modal'
import { addFilter } from '../../../dashboard-state'
import BreakdownModal from './../breakdown-modal'
import * as url from '../../../util/url'
import { useDashboardStateContext } from '../../../dashboard-state-context'
import { useSiteContext } from '../../../site-context'
import { browserIconFor } from '../../devices'
import chooseMetrics from './choose-metrics'
import { SortDirection } from '../../../hooks/use-order-by'

function BrowserVersionsModal() {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  const reportInfo = {
    title: 'Browser versions',
    dimension: 'browser_version',
    endpoint: url.apiPath(site, '/browser-versions'),
    dimensionLabel: 'Browser version',
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

  const renderIcon = useCallback(
    (listItem) => browserIconFor(listItem.browser),
    []
  )

  return (
    <Modal>
      <BreakdownModal
        reportInfo={reportInfo}
        metrics={chooseMetrics(dashboardState, site)}
        getFilterInfo={getFilterInfo}
        addSearchFilter={addSearchFilter}
        renderIcon={renderIcon}
      />
    </Modal>
  )
}

export default BrowserVersionsModal
