import React from "react"
import FilterModalRow from "./filter-modal-row"
import { formattedFilters } from '../../util/filters'

export default function FilterModalGroup({
  type,
  rows,
  site,
  query,
  onUpdateRowValue,
  onAddRow
}) {
  const showAddRow = type == 'props'
  const showTitle = type != 'props'

  return (
    <>
      <div className="mt-4">
        {showTitle && (<div className="text-sm font-medium text-gray-700 dark:text-gray-300">{formattedFilters[type]}</div>)}
        {rows.map(({ id, filter }) => (
          <FilterModalRow
            key={id}
            filter={filter}
            site={site}
            query={query}
            onUpdate={(newFilter, labelUpdate) => onUpdateRowValue(id, newFilter, labelUpdate)}
          />
        ))}
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
