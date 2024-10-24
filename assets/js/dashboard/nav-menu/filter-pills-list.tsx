/** @format */

import React, { DetailedHTMLProps, HTMLAttributes } from 'react'
import { useQueryContext } from '../query-context'
import { FilterPill } from './filter-pill'
import {
  cleanLabels,
  EVENT_PROPS_PREFIX,
  FILTER_GROUP_TO_MODAL_TYPE,
  plainFilterText,
  styledFilterText
} from '../util/filters'
import { useAppNavigate } from '../navigation/use-app-navigate'
import classNames from 'classnames'

export const PILL_X_GAP = 16
export const PILL_Y_GAP = 8

/** Restricts output to slice of DashboardQuery['filters'], or makes the output outside the slice invisible */
type Slice = {
  /** The beginning index of the specified portion of the array. If start is undefined, then the slice begins at index 0. */
  start?: number
  /** The end index of the specified portion of the array. This is exclusive of the element at the index 'end'. If end is undefined, then the slice extends to the end of the array. */
  end?: number
  /** Determines if it renders the elements outside the slice with invisible or doesn't render the elements at all */
  type: 'hide-outside' | 'no-render-outside'
}

type FilterPillsProps = {
  direction: 'horizontal' | 'vertical'
  slice?: Slice
} & DetailedHTMLProps<HTMLAttributes<HTMLDivElement>, HTMLDivElement>

export const FilterPillsList = React.forwardRef<
  HTMLDivElement,
  FilterPillsProps
>(({ className, style, slice, direction }, ref) => {
  const { query } = useQueryContext()
  const navigate = useAppNavigate()

  const renderableFilters =
    slice?.type === 'no-render-outside'
      ? query.filters.slice(slice.start, slice.end)
      : query.filters

  const indexAdjustment =
    slice?.type === 'no-render-outside' ? (slice.start ?? 0) : 0

  const isInvisible = (index: number) => {
    return slice?.type === 'hide-outside'
      ? index < (slice.start ?? 0) ||
          index > (slice.end ?? query.filters.length) - 1
      : false
  }

  return (
    <div
      ref={ref}
      className={classNames(
        'flex',
        {
          'flex-row': direction === 'horizontal',
          'flex-col items-start': direction === 'vertical'
        },
        className
      )}
      style={{ columnGap: PILL_X_GAP, rowGap: PILL_Y_GAP, ...style }}
    >
      {renderableFilters.map((filter, index) => (
        <FilterPill
          className={classNames(isInvisible(index) && 'invisible')}
          modalToOpen={
            FILTER_GROUP_TO_MODAL_TYPE[
              filter[1].startsWith(EVENT_PROPS_PREFIX) ? 'props' : filter[1]
            ]
          }
          plainText={plainFilterText(query, filter)}
          key={index}
          onRemoveClick={() =>
            navigate({
              search: (search) => ({
                ...search,
                filters: query.filters.filter(
                  (_, i) => i !== index + indexAdjustment
                ),
                labels: cleanLabels(query.filters, query.labels)
              })
            })
          }
        >
          {styledFilterText(query, filter)}
        </FilterPill>
      ))}
    </div>
  )
})
