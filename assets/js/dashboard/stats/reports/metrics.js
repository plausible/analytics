import numberFormatter from "../../util/number-formatter"
import React from "react"

export const VISITORS_METRIC = {
  name: 'visitors',
  label: 'Visitors',
  realtimeLabel: 'Current visitors',
  goalFilterLabel: 'Conversions'
}
export const UNIQUE_ENTRANCES_METRIC = {
  ...VISITORS_METRIC,
  name: 'unique_entrances',
  label: 'Unique Entrances'
}
export const UNIQUE_EXITS_METRIC = {
  ...VISITORS_METRIC,
  name: 'unique_exits',
  label: 'Unique Exits'
}
export const PERCENTAGE_METRIC = { name: 'percentage', label: '%' }
export const CR_METRIC = { name: 'conversion_rate', label: 'CR' }

export function maybeWithCR(metrics, query) {
  if (metrics.includes(PERCENTAGE_METRIC) && query.filters.goal) {
    return metrics.filter((m) => { return m !== PERCENTAGE_METRIC }).concat([CR_METRIC])
  }
  else if (query.filters.goal) {
    return metrics.concat(CR_METRIC)
  }
  else {
    return metrics
  }
}

export function displayMetricValue(value, metric) {
  if (metric === PERCENTAGE_METRIC) {
    return value
  } else if (metric === CR_METRIC) {
    return `${value}%`
  } else {
    return <span tooltip={value}>{ numberFormatter(value) }</span>
  }
}

export function metricLabelFor(metric, query) {
  if (metric.realtimeLabel && query.period === 'realtime') { return metric.realtimeLabel }
  if (metric.goalFilterLabel && query.filters.goal) { return metric.goalFilterLabel }
  return metric.label
}