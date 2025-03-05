import React, { useCallback, useEffect, useState } from "react";
import ListReport, { MIN_HEIGHT } from "../reports/list";
import Combobox from '../../components/combobox';
import * as metrics from '../reports/metrics';
import * as api from '../../api';
import * as url from '../../util/url';
import * as storage from "../../util/storage";
import { EVENT_PROPS_PREFIX, getGoalFilter, FILTER_OPERATIONS, hasConversionGoalFilter } from "../../util/filters";
import classNames from "classnames";
import { useQueryContext } from "../../query-context";
import { useSiteContext } from "../../site-context";
import { customPropsRoute } from "../../router";


export default function Properties({ afterFetchData }) {
  const { query } = useQueryContext();
  const site = useSiteContext();

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
    setPropKeyLoading(true)
    setPropKey(null)

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
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query])

  function getPropKeyFromStorage() {
    if (singleGoalFilterApplied()) {
      const storedForGoal = storage.getItem(propKeyStorageNameForGoal())
      if (storedForGoal) { return storedForGoal }
    }

    return storage.getItem(propKeyStorageName)
  }

  function fetchProps() {
    return api.get(site, url.apiPath(site,  `/custom-prop-values/${encodeURIComponent(propKey)}`), query)
  }

  const fetchPropKeyOptions = useCallback(() => {
    return (input) => {
      return api.get(site, url.apiPath(site,  "/suggestions/prop_key"), query, { q: input.trim() })
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
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
  function chooseMetrics() {
    return [
      metrics.createVisitors({ renderLabel: (_query) => "Visitors", meta: { plot: true } }),
      metrics.createEvents({ renderLabel: (_query) => "Events", meta: { hiddenOnMobile: true } }),
      hasConversionGoalFilter(query) && metrics.createConversionRate(),
      !hasConversionGoalFilter(query) && metrics.createPercentage(),
      BUILD_EXTRA && metrics.createTotalRevenue({ meta: { hiddenOnMobile: true } }),
      BUILD_EXTRA && metrics.createAverageRevenue({ meta: { hiddenOnMobile: true } })
    ].filter(metric => !!metric)
  }

  function renderBreakdown() {
    return (
      <ListReport
        fetchData={fetchProps}
        afterFetchData={afterFetchData}
        getFilterFor={getFilterFor}
        keyLabel={propKey}
        metrics={chooseMetrics()}
        detailsLinkProps={{ path: customPropsRoute.path, params: { propKey }, search: (search) => search }}
        maybeHideDetails={true}
        color="bg-red-50"
        colMinWidth={90}
      />
    )
  }

  const getFilterFor = (listItem) => ({
    prefix: `${EVENT_PROPS_PREFIX}${propKey}`,
    filter: ["is", `${EVENT_PROPS_PREFIX}${propKey}`, [listItem.name]]
  })

  const comboboxDisabled = !propKeyLoading && !propKey
  const comboboxPlaceholder = comboboxDisabled ? 'No custom properties found' : ''
  const comboboxValues = propKey ? [{ value: propKey, label: propKey }] : []
  const boxClass = classNames('pl-2 pr-8 py-1 bg-transparent dark:text-gray-300 rounded-md shadow-sm border border-gray-300 dark:border-gray-500', {
    'pointer-events-none': comboboxDisabled
  })

  const COMBOBOX_HEIGHT = 40

  return (
    <div className="w-full mt-4" style={{ minHeight: `${COMBOBOX_HEIGHT + MIN_HEIGHT}px` }}>
      <div style={{ minHeight: `${COMBOBOX_HEIGHT}px` }}>
        <Combobox boxClass={boxClass} forceLoading={propKeyLoading} fetchOptions={fetchPropKeyOptions()} singleOption={true} values={comboboxValues} onSelect={onPropKeySelect()} placeholder={comboboxPlaceholder} />
      </div>
      {propKey && renderBreakdown()}
    </div>
  )
}
