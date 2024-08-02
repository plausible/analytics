import React, { useCallback } from "react";
import Modal from './modal'
import { hasGoalFilter, isRealTimeDashboard } from "../../util/filters";
import { addFilter } from '../../query'
import BreakdownModal from "./breakdown-modal";
import * as metrics from '../reports/metrics'
import * as url from '../../util/url';
import { useQueryContext } from "../../query-context";
import { useSiteContext } from "../../site-context";
import { browserIconFor, osIconFor, screenSizeIconFor } from "../devices";

const VIEWS = {
  browsers: {
    info: { title: 'Browsers', dimension: 'browser', endpoint: '/browsers', dimensionLabel: 'Browser' },
    renderIcon: (listItem) => browserIconFor(listItem.name)
  },
  browser_versions: {
    info: { title: 'Browser Versions', dimension: 'browser_version', endpoint: '/browser-versions', dimensionLabel: 'Browser version' },
    renderIcon: (listItem) => browserIconFor(listItem.browser)
  },
  operating_systems: {
    info: { title: 'Operating Systems', dimension: 'os', endpoint: '/operating-systems', dimensionLabel: 'Operating system' },
    renderIcon: (listItem) => osIconFor(listItem.name)
  },
  operating_system_versions: {
    info: { title: 'Operating System Versions', dimension: 'os_version', endpoint: '/operating-system-versions', dimensionLabel: 'Operating system version' },
    renderIcon: (listItem) => osIconFor(listItem.os)
  },
  screen_sizes: {
    info: { title: 'Screen Sizes', dimension: 'screen', endpoint: '/screen-sizes', dimensionLabel: 'Screen size' },
    renderIcon: (listItem) => screenSizeIconFor(listItem.name)
  },
}

function DevicesModal({ currentView }) {
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
        metrics.createVisitors({ renderLabel: (_query) => 'Current visitors' }),
        metrics.createPercentage()
      ]
    }

    return [
      metrics.createVisitors({ renderLabel: (_query) => "Visitors" }),
      metrics.createPercentage(),
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

export default DevicesModal
