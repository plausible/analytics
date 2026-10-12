import React, { CSSProperties } from 'react'
import { useDashboardStateContext } from '../dashboard-state-context'
import { FilterPill, FilterPillAction } from './filter-pill'
import { cleanLabels, EVENT_PROPS_PREFIX } from '../util/filters'
import { styledFilterText, plainFilterText } from '../util/filter-text'
import { useAppNavigate } from '../navigation/use-app-navigate'
import classNames from 'classnames'
import { filterRoute } from '../router'
import { canRemoveFilter, isSegmentFilter } from '../filtering/segments'
import { useSegmentsContext } from '../filtering/segments-context'
import { SegmentPillMenu } from './segments/segment-pill-menu'
import { Filter } from '../dashboard-state'

export const AppliedFilterPillsList = React.forwardRef<
  HTMLDivElement,
  { className?: string; style?: CSSProperties }
>(({ className, style }, ref) => {
  const { dashboardState } = useDashboardStateContext()
  const { segments, limitedToSegment } = useSegmentsContext()
  const navigate = useAppNavigate()

  const getPillAction = (filter: Filter): FilterPillAction | undefined => {
    if (!isSegmentFilter(filter)) {
      return {
        type: 'link',
        navigationTarget: {
          path: filterRoute.path,
          search: (s) => s,
          params: {
            field: filter[1].startsWith(EVENT_PROPS_PREFIX)
              ? 'props'
              : filter[1]
          }
        }
      }
    }
    const [_operation, _dimension, [id]] = filter
    const segment = segments.find((s) => String(s.id) === String(id))
    if (!segment) {
      return undefined
    }
    return {
      type: 'menu',
      renderMenu: (closeMenu) => (
        <SegmentPillMenu segment={segment} closeMenu={closeMenu} />
      )
    }
  }

  return (
    // the negative margin hides the inner padding, which keeps
    // pill focus rings visible when the pills scroll
    <div className="-m-1 min-w-0">
      <div
        ref={ref}
        className={classNames('flex gap-x-1 p-1', className)}
        style={style}
      >
        {dashboardState.filters.map((filter, index) => (
          <FilterPill
            key={index}
            plainText={plainFilterText(dashboardState, filter)}
            action={getPillAction(filter)}
            onRemoveClick={
              canRemoveFilter(filter, limitedToSegment)
                ? () => {
                    const newFilters = dashboardState.filters.filter(
                      (_, i) => i !== index
                    )

                    navigate({
                      search: (searchRecord) => ({
                        ...searchRecord,
                        filters: newFilters,
                        labels: cleanLabels(newFilters, dashboardState.labels)
                      })
                    })
                  }
                : undefined
            }
          >
            {styledFilterText(dashboardState, filter)}
          </FilterPill>
        ))}
      </div>
    </div>
  )
})
