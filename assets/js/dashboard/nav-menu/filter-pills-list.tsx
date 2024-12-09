/** @format */

import React, { DetailedHTMLProps, HTMLAttributes } from 'react'
import { useQueryContext } from '../query-context'
import { FilterPill, FilterPillProps } from './filter-pill'
import {
  cleanLabels,
  EVENT_PROPS_PREFIX,
  FILTER_GROUP_TO_MODAL_TYPE,
  plainFilterText,
  styledFilterText
} from '../util/filters'
import { useAppNavigate } from '../navigation/use-app-navigate'
import classNames from 'classnames'
import { filterRoute } from '../router'

export const PILL_X_GAP = 8
export const PILL_Y_GAP = 0

type SliceStartEnd = {
  /** The beginning index of the specified portion of the array. If start is undefined, then the slice begins at index 0. */
  start?: number
  /** The end index of the specified portion of the array. This is exclusive of the element at the index 'end'. If end is undefined, then the slice extends to the end of the array. */
  end?: number
}

type InvisibleOutsideSlice = {
  type: 'invisible-outside'
} & SliceStartEnd

type NoRenderOutsideSlice = {
  type: 'no-render-outside'
} & SliceStartEnd

type AppliedFilterPillsListProps = Omit<
  FilterPillsListProps,
  'slice' | 'pillProps' | 'pills'
> & { slice?: InvisibleOutsideSlice | NoRenderOutsideSlice }

type FilterPillsListProps = {
  direction: 'horizontal' | 'vertical'
} & DetailedHTMLProps<HTMLAttributes<HTMLDivElement>, HTMLDivElement> & {
    pills: FilterPillProps[]
  }

export const AppliedFilterPillsList = React.forwardRef<
  HTMLDivElement,
  AppliedFilterPillsListProps
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
    return slice?.type === 'invisible-outside'
      ? index < (slice.start ?? 0) ||
          index > (slice.end ?? query.filters.length) - 1
      : false
  }

  return (
    <FilterPillsList
      pills={renderableFilters.map((filter, index) => ({
        className: classNames(isInvisible(index) && 'invisible'),
        plainText: plainFilterText(query.labels, filter),
        children: styledFilterText(query.labels, filter),
        interactive: {
          navigationTarget: {
            path: filterRoute.path,
            search: (s) => s,
            params: {
              field:
                FILTER_GROUP_TO_MODAL_TYPE[
                  filter[1].startsWith(EVENT_PROPS_PREFIX) ? 'props' : filter[1]
                ]
            }
          },
          onRemoveClick: () => {
            const newFilters = query.filters.filter(
              (_, i) => i !== index + indexAdjustment
            )

            navigate({
              search: (search) => ({
                ...search,
                filters: newFilters,
                labels: cleanLabels(newFilters, query.labels)
              })
            })
          }
        }
      }))}
      className={className}
      style={style}
      ref={ref}
      direction={direction}
    />
  )
})

export const FilterPillsList = React.forwardRef<
  HTMLDivElement,
  FilterPillsListProps
>(({ className, style, direction, pills }, ref) => {
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
      {pills.map((options, index) => (
        <FilterPill key={index} {...options} />
      ))}
    </div>
  )
})
