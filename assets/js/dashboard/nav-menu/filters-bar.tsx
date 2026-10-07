import { StarIcon } from '@heroicons/react/24/outline'
import classNames from 'classnames'
import React, { ReactNode, useEffect, useRef } from 'react'
import { AppliedFilterPillsList } from './filter-pills-list'
import { FilterMenu } from './filter-menu'
import { useDashboardStateContext } from '../dashboard-state-context'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import { popover } from '../components/popover'
import { QuestionMarkCircleIcon, TrashIcon } from '../components/icons'
import { Tooltip } from '../util/tooltip'
import {
  canSeeSaveAsSegmentAction,
  isSegmentFilter
} from '../filtering/segments'
import { useRoutelessModalsContext } from '../navigation/routeless-modals-context'
import { DashboardState } from '../dashboard-state'
import { useUserContext } from '../user-context'
import { useScrollFadeMask } from '../hooks/use-scroll-fade-mask'

const canShowClearAllAction = ({
  filters
}: Pick<DashboardState, 'filters'>): boolean => filters.length >= 1

const canShowSaveAsSegmentAction = ({
  filters,
  isEditingSegment
}: Pick<DashboardState, 'filters'> & { isEditingSegment: boolean }): boolean =>
  filters.length >= 1 && !filters.some(isSegmentFilter) && !isEditingSegment

export const FiltersBar = () => {
  const { dashboardState, expandedSegment } = useDashboardStateContext()
  const user = useUserContext()

  const showingClearAll = canShowClearAllAction({
    filters: dashboardState.filters
  })
  const showingSaveAsSegment =
    canShowSaveAsSegmentAction({
      filters: dashboardState.filters,
      isEditingSegment: !!expandedSegment
    }) && canSeeSaveAsSegmentAction({ user })

  const hasActions = showingSaveAsSegment || showingClearAll

  if (!dashboardState.filters.length) {
    return (
      <div className="flex flex-1 justify-end">
        <FilterMenu />
      </div>
    )
  }

  return (
    <div className="flex items-center gap-x-1 md:min-w-0">
      <ScrollableFilterPills />
      <div className="flex shrink-0 items-center gap-x-1">
        <FilterMenu compact />
        {hasActions && (
          <div
            aria-hidden="true"
            className="mx-1 h-4 w-px bg-gray-300 dark:bg-gray-600"
          />
        )}
        {showingSaveAsSegment && <SaveAsSegmentAction />}
        {showingClearAll && <ClearAction />}
      </div>
    </div>
  )
}

const ScrollableFilterPills = () => {
  const { dashboardState } = useDashboardStateContext()
  const { ref, maskImage, update } = useScrollFadeMask<HTMLDivElement>()
  const filtersCount = dashboardState.filters.length
  const previousFiltersCount = useRef(filtersCount)

  useEffect(() => {
    const element = ref.current
    if (!element) {
      return
    }
    // new filters are prepended, so bring the start into view when one is added
    if (filtersCount > previousFiltersCount.current) {
      element.scrollLeft = 0
    }
    previousFiltersCount.current = filtersCount
    update()
  }, [ref, update, dashboardState.filters, filtersCount])

  return (
    <AppliedFilterPillsList
      ref={ref}
      className="md:overflow-x-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
      style={{ maskImage }}
    />
  )
}

const actionClassName = classNames(
  popover.toggleButton.classNames.rounded,
  popover.toggleButton.classNames.ghost,
  'justify-center'
)

const ActionTooltip = ({
  label,
  keybind,
  children,
  docsLink
}: {
  label: string
  keybind?: string
  children: ReactNode
  docsLink?: { href: string; label: string }
}) => (
  <Tooltip
    interactive={!!docsLink}
    containerRef={{ current: document.body }}
    info={
      <span className="flex items-center gap-x-2 whitespace-nowrap">
        {label}
        {keybind && (
          <kbd className="rounded-sm border border-gray-600 dark:border-gray-500 px-1 font-sans text-xs text-gray-300">
            {keybind}
          </kbd>
        )}
        {docsLink && (
          <a
            href={docsLink.href}
            target="_blank"
            rel="noreferrer"
            aria-label={docsLink.label}
          >
            <QuestionMarkCircleIcon className="size-4" />
          </a>
        )}
      </span>
    }
  >
    {children}
  </Tooltip>
)

const ClearAction = () => (
  <ActionTooltip label="Clear all filters" keybind="ESC">
    <AppNavigationLink
      aria-label="Clear all filters"
      className={actionClassName}
      search={(search) => ({
        ...search,
        filters: null,
        labels: null
      })}
    >
      <TrashIcon className="block size-4" />
    </AppNavigationLink>
  </ActionTooltip>
)

const SaveAsSegmentAction = () => {
  const { setModal } = useRoutelessModalsContext()

  return (
    <ActionTooltip
      label="Save as segment"
      docsLink={{
        href: 'https://plausible.io/docs/filters-segments#how-to-save-a-segment',
        label: 'Learn more about segments'
      }}
    >
      <AppNavigationLink
        aria-label="Save as segment"
        className={actionClassName}
        search={(s) => s}
        onClick={() => setModal({ type: 'create-segment' })}
        state={{ expandedSegment: null }}
      >
        <StarIcon className="block size-4" />
      </AppNavigationLink>
    </ActionTooltip>
  )
}
