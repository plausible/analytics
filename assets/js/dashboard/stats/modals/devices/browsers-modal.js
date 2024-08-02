import React, { useCallback } from "react";
import Modal from './../modal';
import { addFilter } from '../../../query'
import BreakdownModal from "./../breakdown-modal";
import * as url from '../../../util/url';
import { useQueryContext } from "../../../query-context";
import { useSiteContext } from "../../../site-context";
import { browserIconFor } from "../../devices";
import chooseMetrics from './choose-metrics';

function BrowsersModal() {
  const { query } = useQueryContext();
  const site = useSiteContext();

  const reportInfo = {
    title: 'Browsers',
    dimension: 'browser',
    endpoint: url.apiPath(site, '/browsers'),
    dimensionLabel: 'Browser'
  }

  const getFilterInfo = useCallback((listItem) => {
    return {
      prefix: reportInfo.dimension,
      filter: ["is", reportInfo.dimension, [listItem.name]]
    }
  }, [reportInfo.dimension])

  const addSearchFilter = useCallback((query, searchString) => {
    return addFilter(query, ['contains', reportInfo.dimension, [searchString]])
  }, [reportInfo.dimension])

  const renderIcon = useCallback((listItem) => browserIconFor(listItem.name), [])

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

export default BrowsersModal
