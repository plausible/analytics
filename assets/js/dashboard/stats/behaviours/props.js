import React, { useState } from "react";
import ListReport from "../reports/list";
import Combobox from '../../components/combobox'
import * as api from '../../api'
import * as url from '../../util/url'
import { CR_METRIC, PERCENTAGE_METRIC } from "../reports/metrics";
import * as storage from "../../util/storage";

const DEFAULT_METRICS = [
  {name: 'visitors', label: 'Visitors'},
  {name: 'events', label: 'Events'},
  PERCENTAGE_METRIC
]

const GOAL_FILTER_METRICS = [
  {name: 'visitors', label: 'Uniques'},
  {name: 'events', label: 'Total'},
  CR_METRIC
]

export default function Properties(props) {
  const { site, query } = props
  const propKeyStorageName = `prop_key__${site.domain}`
  const [propKey, setPropKey] = useState(defaultPropKey())

  function defaultPropKey() {
    const stored = storage.getItem(propKeyStorageName)
    if (stored) { return stored }
    return null
  }

  function fetchProps() {    
    return api.get(url.apiPath(site, `/custom-prop-values/${encodeURIComponent(propKey)}`), props.query)
  }

  function fetchPropKeyOptions() {
    return (input) => {
      return api.get(url.apiPath(site, "/suggestions/prop_key"), query, { q: input.trim() })
    }
  }

  function onPropKeySelect() {
    return (selectedOptions) => {
      const newPropKey = selectedOptions.length === 0 ? null : selectedOptions[0].value
      
      if (newPropKey) { storage.setItem(propKeyStorageName, newPropKey) }
      setPropKey(newPropKey)
    }
  }

  function renderBreakdown() {
    return (
      <ListReport
        fetchData={fetchProps}
        getFilterFor={getFilterFor}
        keyLabel={propKey}
        metrics={metrics()}
        query={query}
        color="bg-gray-200"
      />
    )
  }

  function metrics() {
    if (query.filters.goal) {
      return GOAL_FILTER_METRICS
    } else {
      return DEFAULT_METRICS
    }
  }

  const getFilterFor = (listItem) => { return {'props': JSON.stringify({propKey: listItem['name']})} }
  const comboboxValues = propKey ? [{value: propKey, label: propKey}] : []

  return (
    <div className="w-full mt-4">
      <div className="flex-col sm:flex-row flex items-center pb-1">
        <span className="text-xs font-bold text-gray-600 dark:text-gray-300 self-start sm:self-auto mb-1 sm:mb-0">
          <Combobox className="mr-2" fetchOptions={fetchPropKeyOptions()} singleOption={true} values={comboboxValues} onSelect={onPropKeySelect()} placeholder={'Select a property'} />
        </span>
      </div>
      { propKey && renderBreakdown() }
    </div>
  )
}