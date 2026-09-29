import React, { CSSProperties } from 'react'
import { useDashboardStateContext } from '../dashboard-state-context'
import { FilterPill, FilterPillAction } from './filter-pill'
import classNames from 'classnames'
import { canRemoveFilter, isSegmentFilter } from '../filtering/segments'
import { useSegmentsContext } from '../filtering/segments-context'
import { SegmentPillMenu } from './segments/segment-pill-menu'
import { Filter } from '../dashboard-state'
import { useFilterEditorContext } from '../filtering/filter-editor-context'

// new filters are inserted before existing ones, so index keys would move
// the state of one pill to another
const getPillKeys = (filters: Filter[]) => {
  const counts: Record<string, number> = {}
  return filters.map(([_operation, key]) => {
    counts[key] = (counts[key] ?? 0) + 1
    return `${key}:${counts[key]}`
  })
}

export const AppliedFilterPillsList = React.forwardRef<
  HTMLDivElement,
  { className?: string; style?: CSSProperties }
>(({ className, style }, ref) => {
  const { dashboardState } = useDashboardStateContext()
  const { segments, limitedToSegment } = useSegmentsContext()
  const editor = useFilterEditorContext()
  const filters = editor.renderedFilters
  const keys = getPillKeys(filters)

  const getPillAction = (filter: Filter): FilterPillAction | undefined => {
    if (!isSegmentFilter(filter)) {
      return { type: 'edit' }
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
        {filters.map((filter, index) => (
          <FilterPill
            key={keys[index]}
            position={index}
            filter={filter}
            labels={dashboardState.labels}
            action={getPillAction(filter)}
            onRemoveClick={
              canRemoveFilter(filter, limitedToSegment)
                ? () => editor.remove(index)
                : undefined
            }
          />
        ))}
      </div>
    </div>
  )
})
