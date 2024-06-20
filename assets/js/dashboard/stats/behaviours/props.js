import React, { useCallback, useEffect, useState } from "react"
import ListReport, { MIN_HEIGHT } from "../reports/list";
import Combobox from '../../components/combobox'
import * as api from '../../api'
import * as url from '../../util/url'
import { CR_METRIC, PERCENTAGE_METRIC } from "../reports/metrics";
import * as storage from "../../util/storage";
import { EVENT_PROPS_PREFIX, getGoalFilter, FILTER_OPERATIONS, hasGoalFilter } from "../../util/filters"


export default function Properties(props) {
  const { site, query } = props
  const propKeyStorageName = `prop_key__${site.domain}`
  const propKeyStorageNameForGoal = () => {
    const [_operation, _filterKey, [goal]] = getGoalFilter(query)
    return `${goal}__prop_key__${site.domain}`
  }

  const [propKey, setPropKey] = useState(null)
  const [propKeyLoading, setPropKeyLoading] = useState(true)

  function singleGoalFilterApplied() {
    const goalFilter = getGoalFilter(query)
    if (goalFilter) {
      const [operation, _filterKey, clauses] = goalFilter
      return operation === FILTER_OPERATIONS.is && clauses.length === 1
    } else {
      return false
    }
  }

  useEffect(() => {
    fetchPropKeyOptions()("").then((propKeys) => {
      const propKeyValues = propKeys.map(entry => entry.value)

      if (propKeyValues.length > 0) {
        const storedPropKey = getPropKeyFromStorage()

        if (propKeyValues.includes(storedPropKey)) {
          setPropKey(storedPropKey)
        } else {
          setPropKey(propKeys[0].value)
        }
      }

      setPropKeyLoading(false)
    })
  }, [query])

  function getPropKeyFromStorage() {
    if (singleGoalFilterApplied()) {
      const storedForGoal = storage.getItem(propKeyStorageNameForGoal())
      if (storedForGoal) { return storedForGoal }
    }

    return storage.getItem(propKeyStorageName)
  }

  async function fetchProps() {
    await new Promise(r => setTimeout(r, 600))
    return api.get(url.apiPath(site, `/custom-prop-values/${encodeURIComponent(propKey)}`), query)
  }

  const fetchPropKeyOptions = useCallback(() => {
    return async (input) => {
      await new Promise(r => setTimeout(r, 600))
      return api.get(url.apiPath(site, "/suggestions/prop_key"), query, { q: input.trim() })
    }
  }, [query])

  function onPropKeySelect() {
    return (selectedOptions) => {
      const newPropKey = selectedOptions.length === 0 ? null : selectedOptions[0].value

      if (newPropKey) {
        const storageName = singleGoalFilterApplied() ? propKeyStorageNameForGoal() : propKeyStorageName
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
        afterFetchData={props.afterFetchData}
        getFilterFor={getFilterFor}
        keyLabel={propKey}
        metrics={[
          { name: 'visitors', label: 'Visitors', plot: true },
          { name: 'events', label: 'Events', hiddenOnMobile: true },
          hasGoalFilter(query) ? CR_METRIC : PERCENTAGE_METRIC,
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

  const getFilterFor = (listItem) => ({
    prefix: `${EVENT_PROPS_PREFIX}${propKey}`,
    filter: ["is", `${EVENT_PROPS_PREFIX}${propKey}`, [listItem.name]]
  })

  const comboboxValues = propKey ? [{ value: propKey, label: propKey }] : []
  const boxClass = 'pl-2 pr-8 py-1 bg-transparent dark:text-gray-300 rounded-md shadow-sm border border-gray-300 dark:border-gray-500'

  const COMBOBOX_HEIGHT = 40

  return (
    <div className="w-full mt-4" style={{ minHeight: `${COMBOBOX_HEIGHT + MIN_HEIGHT}px` }}>
      <div style={{ minHeight: `${COMBOBOX_HEIGHT}px` }}>
        <Combobox boxClass={boxClass} forceLoading={propKeyLoading} fetchOptions={fetchPropKeyOptions()} singleOption={true} values={comboboxValues} onSelect={onPropKeySelect()} placeholder={''} />
      </div>
      {propKey && renderBreakdown()}
    </div>
  )
}
