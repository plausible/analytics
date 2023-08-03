import React from "react"
import Conversions from './conversions'
import ListReport from "../reports/list"
import { CR_METRIC } from "../reports/metrics"
import * as url from "../../util/url"
import * as api from "../../api"

export function specialTitleWhenGoalFilter(query, defaultTitle) {
  switch (query.filters.goal) {
    case '404':
      return '404 Pages'
    case 'Outbound Link: Click':
      return 'Outbound Links'
    case 'File Download':
      return 'File Downloads'
    default:
      return defaultTitle
  }
}

function UrlBreakdown(props) {
  const { site, query } = props

  function fetchData() {
    return api.get(url.apiPath(site, '/custom-prop-values/url'), query)
  }

  const getFilterFor = (listItem) => { return {'props': JSON.stringify({url: listItem['name']})} }

  return (
    <ListReport
      fetchData={fetchData}
      getFilterFor={getFilterFor}
      keyLabel={'url'}
      metrics={[
        {name: 'visitors', label: 'Visitors', plot: true},
        {name: 'events', label: 'Events', hiddenOnMobile: true},
        CR_METRIC
      ]}
      moreLink={url.sitePath(site, `/custom-prop-values/url`)}
      query={query}
      color="bg-red-50"
      colMinWidth={90}
    />
  )
}

export default function GoalConversions(props) {
  const {site, query} = props

  if (['404', 'Outbound Link: Click', 'File Download'].includes(query.filters.goal)) {
    return <UrlBreakdown site={site} query={props.query}/>
  } else {
    return <Conversions site={site} query={props.query} />
  }
}
