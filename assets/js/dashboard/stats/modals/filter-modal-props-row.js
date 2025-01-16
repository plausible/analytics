/** @format */

import React, { useMemo } from 'react'
import { TrashIcon } from '@heroicons/react/20/solid'

import FilterOperatorSelector from '../../components/filter-operator-selector'
import Combobox from '../../components/combobox'

import { apiPath } from '../../util/url'
import {
  EVENT_PROPS_PREFIX,
  FILTER_OPERATIONS,
  fetchSuggestions,
  getPropertyKeyFromFilterKey,
  isFreeChoiceFilterOperation
} from '../../util/filters'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'

export default function FilterModalPropsRow({
  filter,
  showDelete,
  disabledOptions,
  onUpdate,
  onDelete
}) {
  const { query } = useQueryContext()
  const site = useSiteContext()
  const [operation, filterKey, clauses] = filter

  const propKey = useMemo(
    () => getPropertyKeyFromFilterKey(filterKey),
    [filterKey]
  )

  const selectedClauses = useMemo(
    () => clauses.map((value) => ({ value, label: value })),
    [clauses]
  )

  function fetchPropKeyOptions(input) {
    return fetchSuggestions(
      apiPath(site, `/suggestions/prop_key`),
      query,
      input
    )
  }

  function fetchPropValueOptions(input) {
    if (
      [FILTER_OPERATIONS.contains, FILTER_OPERATIONS.contains_not].includes(
        operation
      ) ||
      propKey == ''
    ) {
      return Promise.resolve([])
    }
    return fetchSuggestions(
      apiPath(
        site,
        `/suggestions/custom-prop-values/${encodeURIComponent(propKey)}`
      ),
      query,
      input,
      [FILTER_OPERATIONS.isNot, filterKey, ['(none)']]
    )
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
          // eslint-disable-next-line jsx-a11y/no-autofocus
          autoFocus
          values={propKey ? [{ value: propKey, label: propKey }] : []}
          onSelect={onPropKeySelect}
          placeholder="Property"
          disabledOptions={disabledOptions}
        />
      </div>
      <div className="col-span-3 mx-2">
        <FilterOperatorSelector
          isDisabled={!filterKey}
          forFilter={'prop_value'}
          onSelect={(newOperation) =>
            onUpdate([newOperation, filterKey, clauses])
          }
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
          freeChoice={isFreeChoiceFilterOperation(operation)}
        />
      </div>
      {showDelete && (
        <div className="col-span-1 flex flex-col mt-2">
          {/* eslint-disable-next-line jsx-a11y/anchor-is-valid */}
          <a
            className="ml-2 text-red-600 h-5 w-5 cursor-pointer"
            onClick={onDelete}
          >
            <TrashIcon />
          </a>
        </div>
      )}
    </div>
  )
}
