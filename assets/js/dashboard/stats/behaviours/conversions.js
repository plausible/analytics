import React from 'react';
import * as api from '../../api'
import * as url from '../../util/url'
import { escapeFilterValue } from '../../util/filters'

import { CR_METRIC } from '../reports/metrics';
import ListReport from '../reports/list';

export default function Conversions(props) {
  const {site, query} = props

  function fetchConversions() {
    return api.get(url.apiPath(site, '/conversions'), query, {limit: 20})
  }

  function getFilterFor(listItem) {
    return {goal: escapeFilterValue(listItem.name)}
  }

  return (
    <ListReport
      fetchData={fetchConversions}
      getFilterFor={getFilterFor}
      keyLabel="Goal"
      metrics={[
        {name: 'visitors', label: "Uniques", plot: true},
        {name: 'events', label: "Total"},
        CR_METRIC,
        {name: 'total_revenue', label: 'Revenue'},
        {name: 'average_revenue', label: 'Average'}
      ]}
      query={query}
      color="bg-red-50"
    />
  )
}
