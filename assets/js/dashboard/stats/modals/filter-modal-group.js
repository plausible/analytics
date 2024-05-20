import React, { useMemo } from "react"
import FilterModalRow from "./filter-modal-row"
import { formattedFilters, filterType, getPropertyKeyFromFilterKey } from '../../util/filters'
import FilterModalPropsRow from "./filter-modal-props-row"

export default function FilterModalGroup({
  type,
  filterState,
  site,
  labels,
  query,
  onUpdateRowValue,
  onAddRow,
  onDeleteRow
}) {
  const rows = useMemo(
    () => Object.entries(filterState).filter(([_, filter]) => filterType(filter) == type).map(([id, filter]) => ({ id, filter })),
    [type, filterState]
  )

  const disabledOptions = useMemo(
    () => (type == 'props') ? rows.map(({ filter }) => ({ value: getPropertyKeyFromFilterKey(filter[1]) })) : null,
    [rows]
  )

  const showAddRow = type == 'props'
  const showTitle = type != 'props'

  return (
    <>
      <div className="mt-4">
        {showTitle && (<div className="text-sm font-medium text-gray-700 dark:text-gray-300">{formattedFilters[type]}</div>)}
        {rows.map(({ id, filter }) =>
          type === 'props' ? (
            <FilterModalPropsRow
              key={id}
              filter={filter}
              site={site}
              query={query}
              showDelete={rows.length > 1}
              disabledOptions={disabledOptions}
              onUpdate={(newFilter) => onUpdateRowValue(id, newFilter)}
              onDelete={() => onDeleteRow(id)}
            />
          ) : (
            <FilterModalRow
              key={id}
              filter={filter}
              site={site}
              query={query}
              labels={labels}
              onUpdate={(newFilter, labelUpdate) => onUpdateRowValue(id, newFilter, labelUpdate)}
            />
          )
        )}
      </div>
      {showAddRow && (
        <div className="mt-6">
          <a className="underline text-indigo-500 text-sm cursor-pointer" onClick={() => onAddRow(type)}>
            + Add another
          </a>
        </div>
      )}
    </>
  )
}
