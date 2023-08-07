import React from "react"
import Conversions from './conversions'
import ListReport from "../reports/list"
import { CR_METRIC } from "../reports/metrics"
import * as url from "../../util/url"
import * as api from "../../api"

const SPECIAL_GOALS = {
  '404': {title: '404 Pages', prop: 'path'},
  'Outbound Link: Click': {title: 'Outbound Links', prop: 'url'},
  'Cloaked Link: Click': {title: 'Cloaked Links', prop: 'url'},
  'File Download': {title: 'File Downloads', prop: 'url'}
}

export function specialTitleWhenGoalFilter(query, defaultTitle) {
  return SPECIAL_GOALS[query.filters.goal]?.title || defaultTitle
}

function SpecialPropBreakdown(props) {
  const { site, query } = props
  const prop = SPECIAL_GOALS[query.filters.goal].prop
  
  function fetchData() {
    return api.get(url.apiPath(site, `/custom-prop-values/${prop}`), query)
  }

  function externalLinkDest() {
    if (prop === 'path') {
      return (listItem) => url.externalLinkForPage(site.domain, listItem.name)
    } else {
      return (listItem) => listItem.name
    }
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
      detailsLink={url.sitePath(site, `/custom-prop-values/${prop}`)}
      externalLinkDest={externalLinkDest()}
      maybeHideDetails={true}
      query={query}
      color="bg-red-50"
      colMinWidth={90}
    />
  )
}

export default function GoalConversions(props) {
  const {site, query} = props

  if (SPECIAL_GOALS[query.filters.goal]) {
    return <SpecialPropBreakdown site={site} query={props.query} />
  } else {
    return <Conversions site={site} query={props.query} />
  }
}
