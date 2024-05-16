import React, { useMemo } from "react"
import { TrashIcon } from '@heroicons/react/20/solid'

import FilterTypeSelector from "../../components/filter-type-selector"
import Combobox from '../../components/combobox'

import * as api from '../../api'
import { apiPath } from '../../util/url'
import { EVENT_PROPS_PREFIX, FILTER_OPERATIONS } from '../../util/filters'

export default function FilterModalPropsRow({
  site,
  query,
  filter,
  showDelete,
  onUpdate,
  onDelete,
}) {
  const [operation, filterKey, clauses] = filter

  const propKey = useMemo(
    () => filterKey.slice(EVENT_PROPS_PREFIX.length),
    [filterKey]
  )

  const selectedClauses = useMemo(
    () => clauses.map((value) => ({ value, label: value })),
    [clauses]
  )

  function fetchPropKeyOptions(input) {
    return api.get(apiPath(site, "/suggestions/prop_key"), query, { q: input.trim() })
  }

  function fetchPropValueOptions(_input) {
    // :TODO: Handle this properly with negation
    if (operation === FILTER_OPERATIONS.contains) {
      return Promise.resolve([])
    }
    return Promise.resolve([])

    // const key = propKey?.value
    // const updatedQuery = { ...query, filters: { ...query.filters, props: { [key]: '!(none)' } } }
    // return api.get(apiPath(site, "/suggestions/prop_value"), updatedQuery, { q: input.trim() })
  }

  function onPropKeySelect(selection) {
    const { value } = selection[0]
    onUpdate([operation, `${EVENT_PROPS_PREFIX}${value}`, clauses])
  }

  function onPropValueSelect(selection) {
    const newClauses = selection.map(({ value }) => value)
    onUpdate([operation, filterKey, newClauses])
  }

  return (
    <div className="grid grid-cols-12 mt-6">
      <div className="col-span-4">
        <Combobox
          className="mr-2"
          fetchOptions={fetchPropKeyOptions}
          singleOption
          autoFocus
          values={propKey ? [{ value: propKey, label: propKey }] : []}
          onSelect={onPropKeySelect}
          placeholder="Property"
          // :TODO: Disable all other selected prop keys
          disabledOptions={[]}
        />
      </div>
      <div className="col-span-3 mx-2">
        <FilterTypeSelector
          isDisabled={!filterKey}
          forFilter={'prop_value'}
          onSelect={(newOperation) => onUpdate([newOperation, filterKey, clauses])}
          selectedType={operation}
        />
      </div>
      <div className="col-span-4">
        <Combobox
          isDisabled={!filterKey}
          fetchOptions={fetchPropValueOptions}
          values={selectedClauses}
          onSelect={onPropValueSelect}
          placeholder={'Value'}
          freeChoice={operation == FILTER_OPERATIONS.contains}
        />
      </div>
      {showDelete && (
        <div className="col-span-1 flex flex-col justify-center">
          <a className="ml-2 text-red-600 h-5 w-5 cursor-pointer" onClick={onDelete}>
            <TrashIcon />
          </a>
        </div>
      )}
    </div>
  )
}
