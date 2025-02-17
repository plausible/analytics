/** @format */

import React from 'react'
import MetricValue from './metric-value'
import { hasConversionGoalFilter } from '../../util/filters'

// Class representation of a metric.

// Metric instances can be created directly via the Metric constructor,
// or using special creator functions like `createVisitors`, which just
// fill out the known fields for that metric.

// ### Required props

// * `key` - the key under which to read values under in an API

// * `formatter` - a function that takes a value of this metric, and
//   and returns the "rendered" version of it. Can be JSX or a string.

// * `renderLabel` - a function rendering a label for this metric given a
//   query argument. Returns string.

// ### Optional props

// * `meta` - a map with extra context for this metric. E.g. `plot`, or
//   `hiddenOnMobile` define some special behaviours in the context where
//   it's used.
export class Metric {
  constructor(props) {
    if (!props.key) {
      throw Error('Required field `key` is missing')
    }
    if (typeof props.renderLabel !== 'function') {
      throw Error('Required field `renderLabel` should be a function')
    }

    this.key = props.key
    this.meta = props.meta || {}
    this.sortable = props.sortable
    this.width = props.width ?? 'w-24'

    this.formatter = props.formatter
    this.renderLabel = props.renderLabel

    this.renderValue = this.renderValue.bind(this)
  }

  renderValue(listItem, meta) {
    return (
      <MetricValue
        listItem={listItem}
        metric={this.key}
        renderLabel={this.renderLabel}
        meta={meta}
        formatter={this.formatter}
      />
    )
  }
}

// Creates a Metric class representing the `visitors` metric.

// Optional props for conveniently generating the `renderLabel` function:

// * `defaultLabel` - label when not realtime, and no goal filter applied
// * `realtimeLabel` - label when realtime period
// * `goalFilterLabel` - label when goal filter is applied
export const createVisitors = (props) => {
  let renderLabel

  if (typeof props.renderLabel === 'function') {
    renderLabel = props.renderLabel
  } else {
    renderLabel = (query) => {
      const defaultLabel = props.defaultLabel || 'Visitors'
      const realtimeLabel = props.realtimeLabel || 'Current visitors'
      const goalFilterLabel = props.goalFilterLabel || 'Conversions'

      if (query.period === 'realtime') {
        return realtimeLabel
      }
      if (query && hasConversionGoalFilter(query)) {
        return goalFilterLabel
      }
      return defaultLabel
    }
  }

  return new Metric({
    width: 'w-24',
    sortable: true,
    ...props,
    key: 'visitors',
    renderLabel
  })
}

export const createConversionRate = (props) => {
  const renderLabel = (_query) => 'CR'
  return new Metric({
    width: 'w-24',
    ...props,
    key: 'conversion_rate',
    renderLabel,
    sortable: true
  })
}

export const createPercentage = (props) => {
  const renderLabel = (_query) => '%'
  return new Metric({
    width: 'w-24',
    ...props,
    key: 'percentage',
    renderLabel,
    sortable: true
  })
}

export const createEvents = (props) => {
  return new Metric({ width: 'w-24', ...props, key: 'events', sortable: true })
}

export const createTotalRevenue = (props) => {
  const renderLabel = (_query) => 'Revenue'
  return new Metric({
    width: 'w-24',
    ...props,
    key: 'total_revenue',
    renderLabel,
    sortable: true
  })
}

export const createAverageRevenue = (props) => {
  const renderLabel = (_query) => 'Average'
  return new Metric({
    width: 'w-24',
    ...props,
    key: 'average_revenue',
    renderLabel,
    sortable: true
  })
}

export const createVisits = (props) => {
  return new Metric({ width: 'w-24', sortable: true, ...props, key: 'visits' })
}

export const createVisitDuration = (props) => {
  const renderLabel = (_query) => 'Visit Duration'
  return new Metric({
    width: 'w-36',
    ...props,
    key: 'visit_duration',
    renderLabel,
    sortable: true
  })
}

export const createBounceRate = (props) => {
  const renderLabel = (_query) => 'Bounce Rate'
  return new Metric({
    width: 'w-28',
    ...props,
    key: 'bounce_rate',
    renderLabel,
    sortable: true
  })
}

export const createPageviews = (props) => {
  const renderLabel = (_query) => 'Pageviews'
  return new Metric({
    width: 'w-28',
    ...props,
    key: 'pageviews',
    renderLabel,
    sortable: true
  })
}

export const createTimeOnPage = (props) => {
  const renderLabel = (_query) => 'Time on Page'
  return new Metric({
    width: 'w-28',
    ...props,
    key: 'time_on_page',
    renderLabel,
    sortable: false
  })
}

export const createExitRate = (props) => {
  const renderLabel = (_query) => 'Exit Rate'
  return new Metric({
    width: 'w-28',
    ...props,
    key: 'exit_rate',
    renderLabel,
    sortable: false
  })
}

export const createScrollDepth = (props) => {
  const renderLabel = (_query) => 'Scroll Depth'
  return new Metric({
    width: 'w-28',
    ...props,
    key: 'scroll_depth',
    renderLabel,
    sortable: true
  })
}
