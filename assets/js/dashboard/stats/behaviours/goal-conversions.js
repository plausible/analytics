import React from 'react'
import Conversions from './conversions'
import ListReport from '../reports/list'
import * as metrics from '../reports/metrics'
import * as url from '../../util/url'
import * as api from '../../api'
import {
  EVENT_PROPS_PREFIX,
  getGoalFilter,
  FILTER_OPERATIONS
} from '../../util/filters'
import { useSiteContext } from '../../site-context'
import { useQueryContext } from '../../query-context'
import { customPropsRoute } from '../../router'

export const SPECIAL_GOALS = {
  404: { title: '404 Pages', prop: 'path' },
  'Outbound Link: Click': { title: 'Outbound Links', prop: 'url' },
  'Cloaked Link: Click': { title: 'Cloaked Links', prop: 'url' },
  'File Download': { title: 'File Downloads', prop: 'url' },
  'WP Search Queries': {
    title: 'WordPress Search Queries',
    prop: 'search_query'
  },
  'WP Form Completions': { title: 'WordPress Form Completions', prop: 'path' }
}

function getSpecialGoal(query) {
  const goalFilter = getGoalFilter(query)
  if (!goalFilter) {
    return null
  }
  const [operation, _filterKey, clauses] = goalFilter
  if (operation === FILTER_OPERATIONS.is && clauses.length == 1) {
    return SPECIAL_GOALS[clauses[0]] || null
  }
  return null
}

export function specialTitleWhenGoalFilter(query, defaultTitle) {
  return getSpecialGoal(query)?.title || defaultTitle
}

function SpecialPropBreakdown({ prop, afterFetchData }) {
  const site = useSiteContext()
  const { query } = useQueryContext()

  function fetchData() {
    return api.get(url.apiPath(site, `/custom-prop-values/${prop}`), query)
  }

  function getExternalLinkUrlFactory() {
    if (prop === 'path') {
      return (listItem) => url.externalLinkForPage(site.domain, listItem.name)
    } else if (prop === 'search_query') {
      return null // WP Search Queries should not become external links
    } else {
      return (listItem) => listItem.name
    }
  }

  function getFilterInfo(listItem) {
    return {
      prefix: EVENT_PROPS_PREFIX,
      filter: ['is', `${EVENT_PROPS_PREFIX}${prop}`, [listItem['name']]]
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({
        renderLabel: (_query) => 'Visitors',
        meta: { plot: true }
      }),
      metrics.createEvents({
        renderLabel: (_query) => 'Events',
        meta: { hiddenOnMobile: true }
      }),
      metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel={prop}
      metrics={chooseMetrics()}
      detailsLinkProps={{
        path: customPropsRoute.path,
        params: { propKey: url.maybeEncodeRouteParam(prop) },
        search: (search) => search
      }}
      getExternalLinkUrl={getExternalLinkUrlFactory()}
      maybeHideDetails={true}
      color="bg-red-50"
      colMinWidth={90}
    />
  )
}

export default function GoalConversions({ afterFetchData, onGoalFilterClick }) {
  const { query } = useQueryContext()

  const specialGoal = getSpecialGoal(query)
  if (specialGoal) {
    return (
      <SpecialPropBreakdown
        prop={specialGoal.prop}
        afterFetchData={afterFetchData}
      />
    )
  } else {
    return (
      <Conversions
        onGoalFilterClick={onGoalFilterClick}
        afterFetchData={afterFetchData}
      />
    )
  }
}
