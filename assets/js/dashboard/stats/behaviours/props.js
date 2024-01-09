import React, { useCallback, useState, useEffect } from "react";
import ListReport from "../reports/list";
import Combobox from '../../components/combobox'
import * as api from '../../api'
import * as url from '../../util/url'
import { CR_METRIC, PERCENTAGE_METRIC } from "../reports/metrics";
import * as storage from "../../util/storage";
import { parsePrefix, escapeFilterValue } from "../../util/filters"


export default function Properties(props) {
  const { site, query } = props
  const propKeyStorageName = `prop_key__${site.domain}`
  const propKeyStorageNameForGoal = `${query.filters.goal}__prop_key__${site.domain}`

  const [propKey, setPropKey] = useState(choosePropKey())

  useEffect(() => {
    setPropKey(choosePropKey())
  }, [query.filters.goal, query.filters.props])

  function singleGoalFilterApplied() {
    const goalFilter = query.filters.goal
    if (goalFilter) {
      const { type, values } = parsePrefix(goalFilter)
      return type === 'is' && values.length === 1
    } else {
      return false
    }
  }

  function choosePropKey() {
    if (query.filters.props) {
      return Object.keys(query.filters.props)[0]
    } else {
      return getPropKeyFromStorage()
    }
  }

  function getPropKeyFromStorage() {
    if (singleGoalFilterApplied()) {
      const storedForGoal = storage.getItem(propKeyStorageNameForGoal)
      if (storedForGoal) { return storedForGoal }
    }

    return storage.getItem(propKeyStorageName)
  }

  function fetchProps() {
    return api.get(url.apiPath(site, `/custom-prop-values/${encodeURIComponent(propKey)}`), query)
  }

  const fetchPropKeyOptions = useCallback(() => {
    return (input) => {
      return api.get(url.apiPath(site, "/suggestions/prop_key"), query, { q: input.trim() })
    }
  }, [query])

  function onPropKeySelect() {
    return (selectedOptions) => {
      const newPropKey = selectedOptions.length === 0 ? null : selectedOptions[0].value

      if (newPropKey) {
        const storageName = singleGoalFilterApplied() ? propKeyStorageNameForGoal : propKeyStorageName
        storage.setItem(storageName, newPropKey)
      }

      setPropKey(newPropKey)
    }
  }

  /*global BUILD_EXTRA*/
  function renderBreakdown() {
    return (
      <ListReport
        fetchData={fetchProps}
        getFilterFor={getFilterFor}
        keyLabel={propKey}
        metrics={[
          { name: 'visitors', label: 'Visitors', plot: true },
          { name: 'events', label: 'Events', hiddenOnMobile: true },
          query.filters.goal ? CR_METRIC : PERCENTAGE_METRIC,
          BUILD_EXTRA && { name: 'total_revenue', label: 'Revenue', hiddenOnMobile: true },
          BUILD_EXTRA && { name: 'average_revenue', label: 'Average', hiddenOnMobile: true }
        ]}
        detailsLink={url.sitePath(site, `/custom-prop-values/${propKey}`)}
        maybeHideDetails={true}
        query={query}
        color="bg-red-50"
        colMinWidth={90}
      />
    )
  }

  const getFilterFor = (listItem) => { return { 'props': JSON.stringify({ [propKey]: escapeFilterValue(listItem.name) }) } }
  const comboboxValues = propKey ? [{ value: propKey, label: propKey }] : []
  const boxClass = 'pl-2 pr-8 py-1 bg-transparent dark:text-gray-300 rounded-md shadow-sm border border-gray-300 dark:border-gray-500'

  return (
    <div className="w-full mt-4">
      <div>
        <Combobox isDisabled={!!query.filters.props} boxClass={boxClass} fetchOptions={fetchPropKeyOptions()} singleOption={true} values={comboboxValues} onSelect={onPropKeySelect()} placeholder={'Select a property'} />
      </div>
      {propKey && renderBreakdown()}
    </div>
  )
}
