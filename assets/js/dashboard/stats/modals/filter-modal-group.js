import React, { useMemo } from "react"
import FilterModalRow from "./filter-modal-row"
import { formattedFilters, getFilterGroup, getPropertyKeyFromFilterKey } from '../../util/filters'
import FilterModalPropsRow from "./filter-modal-props-row"

export default function FilterModalGroup({
  filterGroup,
  filterState,
  site,
  labels,
  query,
  onUpdateRowValue,
  onAddRow,
  onDeleteRow
}) {
  const rows = useMemo(
    () => Object.entries(filterState).filter(([_, filter]) => getFilterGroup(filter) == filterGroup).map(([id, filter]) => ({ id, filter })),
    [filterGroup, filterState]
  )
  const disabledOptions = useMemo(
    () => (filterGroup == 'props') ? rows.map(({ filter }) => ({ value: getPropertyKeyFromFilterKey(filter[1]) })) : null,
    [filterGroup, rows]
  )

  const showAddRow = site.flags.multiple_filters ? !['goal', 'hostname'].includes(filterGroup) : filterGroup == 'props'
  const showTitle = filterGroup != 'props'

  return (
    <>
      <div className="mt-6">
        {showTitle && (<div className="text-sm font-medium text-gray-700 dark:text-gray-300">{formattedFilters[filterGroup]}</div>)}
        {rows.map(({ id, filter }) =>
          filterGroup === 'props' ? (
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
        <div className="mt-2">
          <a className="underline text-indigo-500 text-sm cursor-pointer" onClick={() => onAddRow(filterGroup)}>
            + Add another
          </a>
        </div>
      )}
    </>
  )
}
