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

function SpecialPropBreakdown(props) {
  const { site, query, prop } = props

  function fetchData() {
    return api.get(url.apiPath(site, `/custom-prop-values/${prop}`), query)
  }

  const getFilterFor = (listItem) => { return {'props': JSON.stringify({[prop]: listItem['name']})} }

  return (
    <ListReport
      fetchData={fetchData}
      getFilterFor={getFilterFor}
      keyLabel={prop}
      metrics={[
        {name: 'visitors', label: 'Visitors', plot: true},
        {name: 'events', label: 'Events', hiddenOnMobile: true},
        CR_METRIC
      ]}
      moreLink={url.sitePath(site, `/custom-prop-values/${prop}`)}
      query={query}
      color="bg-red-50"
      colMinWidth={90}
    />
  )
}

export default function GoalConversions(props) {
  const {site, query} = props

  if (query.filters.goal === '404') {
    return <SpecialPropBreakdown site={site} query={props.query} prop="path"/>
  } else if (['Outbound Link: Click', 'File Download'].includes(query.filters.goal)) {
    return <SpecialPropBreakdown site={site} query={props.query} prop="url"/>
  } else {
    return <Conversions site={site} query={props.query} />
  }
}
