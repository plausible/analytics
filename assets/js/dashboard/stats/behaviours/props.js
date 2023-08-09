import React, { useCallback, useState } from "react";
import ListReport from "../reports/list";
import Combobox from '../../components/combobox'
import * as api from '../../api'
import * as url from '../../util/url'
import { CR_METRIC, PERCENTAGE_METRIC } from "../reports/metrics";
import * as storage from "../../util/storage";

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
        metrics={[
          {name: 'visitors', label: 'Visitors', plot: true},
          {name: 'events', label: 'Events', hiddenOnMobile: true},
          query.filters.goal ? CR_METRIC : PERCENTAGE_METRIC,
          {name: 'total_revenue', label: 'Revenue', hiddenOnMobile: true},
          {name: 'average_revenue', label: 'Average', hiddenOnMobile: true}
        ]}
        detailsLink={url.sitePath(site, `/custom-prop-values/${propKey}`)}
        maybeHideDetails={true}
        query={query}
        color="bg-red-50"
        colMinWidth={90}
      />
    )
  }

  const getFilterFor = (listItem) => { return {'props': JSON.stringify({[propKey]: listItem['name']})} }
  const comboboxValues = propKey ? [{value: propKey, label: propKey}] : []
  const boxClass = 'pl-2 pr-8 py-1 bg-transparent dark:text-gray-300 rounded-md shadow-sm border border-gray-300 dark:border-gray-500'

  return (
    <div className="w-full mt-4">
        <div className="w-56">
          <Combobox boxClass={boxClass} fetchOptions={fetchPropKeyOptions()} singleOption={true} values={comboboxValues} onSelect={onPropKeySelect()} placeholder={'Select a property'} />
        </div>
      { propKey && renderBreakdown() }
    </div>
  )
}