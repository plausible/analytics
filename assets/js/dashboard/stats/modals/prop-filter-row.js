import React from 'react'

import Combobox from '../../components/combobox'
import FilterTypeSelector from "../../components/filter-type-selector";
import { FILTER_OPERATIONS } from "../../util/filters";
import * as api from '../../api'
import { apiPath } from '../../util/url'
import { TrashIcon } from '@heroicons/react/20/solid'

function PropFilterRow({
  id,
  query,
  site,
  propKey,
  type,
  clauses,
  showDelete,
  selectedPropKeys,
  onPropKeySelect,
  onPropValueSelect,
  onFilterTypeSelect,
  onPropDelete
}) {
  function fetchPropKeyOptions() {
    return (input) => {
      return api.get(apiPath(site, "/suggestions/prop_key"), query, { q: input.trim() })
    }
  }

  function fetchPropValueOptions() {
    return (input) => {
      if (type === FILTER_OPERATIONS.contains) {
        return Promise.resolve([])
      }


      const key = propKey?.value
      const updatedQuery = { ...query, filters: { ...query.filters, props: { [key]: '!(none)' } } }
      return api.get(apiPath(site, "/suggestions/prop_value"), updatedQuery, { q: input.trim() })
    }
  }

  return (
    <div className="grid grid-cols-12 mt-6">
      <div className="col-span-4">
        <Combobox
          className="mr-2"
          fetchOptions={fetchPropKeyOptions()}
          singleOption
          autoFocus
          values={propKey ? [propKey] : []}
          onSelect={(value) => onPropKeySelect(id, value)}
          placeholder={'Property'}
          disabledOptions={selectedPropKeys}
        />
      </div>
      <div className="col-span-3 mx-2">
        <FilterTypeSelector
          isDisabled={!propKey}
          forFilter={'prop_value'}
          onSelect={(value) => onFilterTypeSelect(id, value)}
          selectedType={type}
        />
      </div>
      <div className="col-span-4">
        <Combobox
          isDisabled={!propKey}
          fetchOptions={fetchPropValueOptions()}
          values={clauses}
          onSelect={(value) => onPropValueSelect(id, value)}
          placeholder={'Value'}
          freeChoice={type == FILTER_OPERATIONS.contains}
        />
      </div>
      {showDelete && (
        <div className="col-span-1 flex flex-col justify-center">
          <a className="ml-2 text-red-600 h-5 w-5 cursor-pointer" onClick={() => onPropDelete(id)}>
            <TrashIcon />
          </a>
        </div>
      )}
    </div>
  )
}

export default PropFilterRow
