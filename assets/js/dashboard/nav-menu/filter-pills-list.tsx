/** @format */

import React, { DetailedHTMLProps, HTMLAttributes, useCallback } from 'react'
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
import { DashboardQuery } from '../query'
import { filterRoute } from '../router'

export const PILL_X_GAP = 16
export const PILL_Y_GAP = 8

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
  'filters' | 'labels' | 'slice' | 'interactive'
> & { slice?: InvisibleOutsideSlice | NoRenderOutsideSlice }

type FilterPillsListProps = {
  direction: 'horizontal' | 'vertical'
  slice?: InvisibleOutsideSlice
} & DetailedHTMLProps<HTMLAttributes<HTMLDivElement>, HTMLDivElement> &
  Pick<DashboardQuery, 'filters' | 'labels'> &
  Pick<FilterPillProps, 'interactive'>

export const AppliedFilterPillsList = React.forwardRef<
  HTMLDivElement,
  AppliedFilterPillsListProps
>(({ className, style, slice, direction }, ref) => {
  const { query } = useQueryContext()
  const navigate = useAppNavigate()

  const modalToOpen =             FILTER_GROUP_TO_MODAL_TYPE[
    filter[1].startsWith(EVENT_PROPS_PREFIX) ? 'props' : filter[1]
  ]

  const renderableFilters =
    slice?.type === 'no-render-outside'
      ? query.filters.slice(slice.start, slice.end)
      : query.filters

  const onRemoveClick = useCallback(() => {
    const newFilters = query.filters.filter((_, i) => i !== 0)
    navigate({
      search: (search) => ({
        ...search,
        filters: newFilters,
        labels: cleanLabels(newFilters, query.labels)
      })
    })
  }, [query.filters, query.labels, navigate])
  
  return (
    <FilterPillsList
      interactive={{
        onRemoveClick,
        navigationTarget: {
          path: filterRoute.path,
          params: { field: 'props' },
          search: (s) => s
        }
      }}
      className={className}
      style={style}
      ref={ref}
      direction={direction}
      filters={renderableFilters}
      labels={query.labels}
      slice={slice?.type === 'invisible-outside' ? slice : undefined}
    />
  )
})

export const FilterPillsList = React.forwardRef<
  HTMLDivElement,
  FilterPillsListProps
>(
  (
    { className, style, slice, filters, labels, direction, interactive },
    ref
  ) => {
    const isInvisible = (index: number) =>
      slice?.type === 'invisible-outside'
        ? index < (slice.start ?? 0) ||
          index > (slice.end ?? filters.length) - 1
        : false

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
        {filters.map((filter, index) => (
          <FilterPill
            key={index}
            interactive={interactive}
            className={classNames(isInvisible(index) && 'invisible')}
            plainText={plainFilterText(labels, filter)}
          >
            {styledFilterText(labels, filter)}
          </FilterPill>
        ))}
      </div>
    )
  }
)
