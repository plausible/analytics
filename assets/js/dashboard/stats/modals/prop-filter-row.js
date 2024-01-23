import React, { useCallback } from 'react'

import Combobox from '../../components/combobox'
import FilterTypeSelector from "../../components/filter-type-selector";
import { FILTER_TYPES } from "../../util/filters";
import * as api from '../../api'
import { apiPath } from '../../util/url'

function PropFilterRow({ query, site, propKey, propValue, onPropKeySelect, onPropValueSelect, onFilterTypeSelect }) {
  function fetchPropKeyOptions() {
    return (input) => {
      return api.get(apiPath(site, "/suggestions/prop_key"), query, { q: input.trim() })
    }
  }

  const fetchPropValueOptions = useCallback(() => {
    return (input) => {
      if (propValue?.type === FILTER_TYPES.contains) {
        return Promise.resolve([])
      }

      const propKey = propKey?.value
      // :TODO: Make sure props is retained
      const updatedQuery = { ...query, filters: { ...query.filters, props: {[propKey]: '!(none)'} } }
      return api.get(apiPath(site, "/suggestions/prop_value"), updatedQuery, { q: input.trim() })
    }
  }, [propKey, propValue])

  function selectedFilterType() {
    return propValue.type
  }

  return (
    <>
      <div className="col-span-4">
        <Combobox className="mr-2" fetchOptions={fetchPropKeyOptions()} singleOption={true} values={propKey ? [propKey] : []} onSelect={onPropKeySelect()} placeholder={'Property'} />
      </div>
      <div className="col-span-3 mx-2">
        <FilterTypeSelector isDisabled={!propKey} forFilter={'prop_value'} onSelect={onFilterTypeSelect()} selectedType={selectedFilterType()} />
      </div>
      <div className="col-span-4">
        <Combobox
          isDisabled={!propKey}
          fetchOptions={fetchPropValueOptions()}
          values={propValue.clauses}
          onSelect={onPropValueSelect()}
          placeholder={'Value'}
          freeChoice={selectedFilterType() == FILTER_TYPES.contains}
        />
      </div>
    </>
  )
}

export default PropFilterRow
