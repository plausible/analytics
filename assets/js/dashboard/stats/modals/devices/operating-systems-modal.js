import React, { useCallback } from 'react'
import Modal from './../modal'
import { addFilter } from '../../../query'
import BreakdownModal from './../breakdown-modal'
import * as url from '../../../util/url'
import { useQueryContext } from '../../../query-context'
import { useSiteContext } from '../../../site-context'
import { osIconFor } from '../../devices'
import chooseMetrics from './choose-metrics'
import { SortDirection } from '../../../hooks/use-order-by'

function OperatingSystemsModal() {
  const { query } = useQueryContext()
  const site = useSiteContext()

  const reportInfo = {
    title: 'Operating Systems',
    dimension: 'os',
    endpoint: url.apiPath(site, '/operating-systems'),
    dimensionLabel: 'Operating system',
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
    (query, searchString) => {
      return addFilter(query, [
        'contains',
        reportInfo.dimension,
        [searchString],
        { case_sensitive: false }
      ])
    },
    [reportInfo.dimension]
  )

  const renderIcon = useCallback((listItem) => osIconFor(listItem.name), [])

  return (
    <Modal>
      <BreakdownModal
        reportInfo={reportInfo}
        metrics={chooseMetrics(query)}
        getFilterInfo={getFilterInfo}
        addSearchFilter={addSearchFilter}
        renderIcon={renderIcon}
      />
    </Modal>
  )
}

export default OperatingSystemsModal
