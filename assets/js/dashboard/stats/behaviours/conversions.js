import React from 'react';
import * as api from '../../api';
import * as url from '../../util/url';

import * as metrics from '../reports/metrics';
import ListReport from '../reports/list';
import { useSiteContext } from '../../site-context';
import { useQueryContext } from '../../query-context';
import { conversionsRoute } from '../../router';

export default function Conversions({ afterFetchData, onGoalFilterClick }) {
  const site = useSiteContext();
  const { query } = useQueryContext()

  function fetchConversions() {
    return api.get(site, url.apiPath(site, '/conversions'), query, { limit: 9 })
  }

  function getFilterFor(listItem) {
    return {
      prefix: "goal",
      filter: ["is", "goal", [listItem.name]],
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ renderLabel: (_query) => "Uniques", meta: { plot: true } }),
      metrics.createEvents({ renderLabel: (_query) => "Total", meta: { hiddenOnMobile: true } }),
      metrics.createConversionRate(),
      BUILD_EXTRA && metrics.createTotalRevenue({ meta: { hiddenOnMobile: true } }),
      BUILD_EXTRA && metrics.createAverageRevenue({ meta: { hiddenOnMobile: true } })
    ].filter(metric => !!metric)
  }

  /*global BUILD_EXTRA*/
  return (
    <ListReport
      fetchData={fetchConversions}
      afterFetchData={afterFetchData}
      getFilterFor={getFilterFor}
      keyLabel="Goal"
      onClick={onGoalFilterClick}
      metrics={chooseMetrics()}
      detailsLinkProps={{ path: conversionsRoute.path, search: (search) => search }}
      color="bg-red-50"
      colMinWidth={90}
    />
  )
}
