import React, { useMemo } from 'react'
import FilterModalRow from './filter-modal-row'
import {
  getFilterDimension,
  getPropertyKeyFromFilterKey
} from '../../util/filters'
import FilterModalPropsRow from './filter-modal-props-row'

export default function FilterModalDimension({
  dimension,
  filterState,
  labels,
  onUpdateRowValue,
  onAddRow,
  onDeleteRow
}) {
  const rows = useMemo(
    () =>
      Object.entries(filterState)
        .filter(([_, filter]) => getFilterDimension(filter) == dimension)
        .map(([id, filter]) => ({ id, filter })),
    [dimension, filterState]
  )
  const disabledOptions = useMemo(
    () =>
      dimension == 'props'
        ? rows.map(({ filter }) => ({
            value: getPropertyKeyFromFilterKey(filter[1])
          }))
        : null,
    [dimension, rows]
  )

  const showAddRow = ['props', 'goal'].includes(dimension)

  return (
    <>
      <div>
        {rows.map(({ id, filter }) =>
          dimension === 'props' ? (
            <FilterModalPropsRow
              testId={id}
              key={id}
              filter={filter}
              showDelete={rows.length > 1}
              disabledOptions={disabledOptions}
              onUpdate={(newFilter) => onUpdateRowValue(id, newFilter)}
              onDelete={() => onDeleteRow(id)}
            />
          ) : (
            <FilterModalRow
              testId={id}
              key={id}
              filter={filter}
              labels={labels}
              canDelete={showAddRow}
              showDelete={rows.length > 1}
              onUpdate={(newFilter, labelUpdate) =>
                onUpdateRowValue(id, newFilter, labelUpdate)
              }
              onDelete={() => onDeleteRow(id)}
            />
          )
        )}
      </div>
      {showAddRow && (
        <div className="mt-2">
          {/* eslint-disable-next-line jsx-a11y/anchor-is-valid */}
          <a
            className="underline text-indigo-500 text-sm cursor-pointer"
            onClick={() => onAddRow(dimension)}
          >
            + Add another
          </a>
        </div>
      )}
    </>
  )
}
