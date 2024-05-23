import React from "react"
import Conversions from './conversions'
import ListReport from "../reports/list"
import { CR_METRIC } from "../reports/metrics"
import * as url from "../../util/url"
import * as api from "../../api"
import { EVENT_PROPS_PREFIX, getGoalFilter } from "../../util/filters"

export const SPECIAL_GOALS = {
  '404': {title: '404 Pages', prop: 'path'},
  'Outbound Link: Click': {title: 'Outbound Links', prop: 'url'},
  'Cloaked Link: Click': {title: 'Cloaked Links', prop: 'url'},
  'File Download': {title: 'File Downloads', prop: 'url'}
}

function getSpecialGoal(query) {
  const goalFilter = getGoalFilter(query)
  if (!goalFilter) {
    return null
  }
  const [_operation, _filterKey, clauses] = goalFilter
  if (clauses.length == 1) {
    return SPECIAL_GOALS[clauses[0]] || null
  }
  return null

}

export function specialTitleWhenGoalFilter(query, defaultTitle) {
  return getSpecialGoal(query)?.title || defaultTitle
}

function SpecialPropBreakdown(props) {
  const { site, query, prop } = props

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

  function getFilterFor(listItem) {
    return {
      prefix: EVENT_PROPS_PREFIX,
      filter: ["is", `${EVENT_PROPS_PREFIX}${prop}`, [listItem['name']]]
    }
  }

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

  const specialGoal = getSpecialGoal(query)
  if (specialGoal) {
    return <SpecialPropBreakdown site={site} query={props.query} prop={specialGoal.prop} />
  } else {
    return <Conversions site={site} query={props.query} onGoalFilterClick={props.onGoalFilterClick}/>
  }
}
