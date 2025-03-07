import React, { useCallback } from "react";
import Modal from './../modal';
import BreakdownModal from "./../breakdown-modal";
import * as url from '../../../util/url';
import { useSiteContext } from "../../../site-context";
import { screenSizeIconFor } from "../../devices";
import chooseMetrics from './choose-metrics';
import { SortDirection } from "../../../hooks/use-order-by";

function ScreenSizesModal() {
  const site = useSiteContext();

  const reportInfo = {
    title: 'Screen Sizes',
    dimension: 'screen',
    endpoint: url.apiPath(site, '/screen-sizes'),
    dimensionLabel: 'Screen size',
    defaultOrder: ["visitors", SortDirection.desc]
  }

  const getFilterInfo = useCallback((listItem) => {
    return {
      prefix: reportInfo.dimension,
      filter: ["is", reportInfo.dimension, [listItem.name]]
    }
  }, [reportInfo.dimension])

  const renderIcon = useCallback((listItem) => screenSizeIconFor(listItem.name), [])

  return (
    <Modal>
      <BreakdownModal
        reportInfo={reportInfo}
        getMetrics={chooseMetrics}
        getFilterInfo={getFilterInfo}
        searchEnabled={false}
        renderIcon={renderIcon}
      />
    </Modal>
  )
}

export default ScreenSizesModal
