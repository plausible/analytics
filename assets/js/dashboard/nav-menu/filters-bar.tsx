/** @format */

import { EllipsisHorizontalIcon } from '@heroicons/react/24/solid'
import classNames from 'classnames'
import React, { useRef, useState, useLayoutEffect, ReactNode } from 'react'
import { AppliedFilterPillsList, PILL_X_GAP_PX } from './filter-pills-list'
import { useQueryContext } from '../query-context'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import { Popover, Transition } from '@headlessui/react'
import { popover } from '../components/popover'
import { BlurMenuButtonOnEscape } from '../keybinding'
import { isSegmentFilter } from '../filtering/segments'
import { useRoutelessModalsContext } from '../navigation/routeless-modals-context'
import { DashboardQuery } from '../query'

// Component structure is
// `..[ filter (x) ]..[ filter (x) ]..[ three dot menu ]..`
// where `..` represents an ideally equal length.
// The following calculations guarantee that.
const BUFFER_RIGHT_PX = 16 - PILL_X_GAP_PX
const BUFFER_LEFT_PX = 16
const SEE_MORE_WIDTH_PX = 36
const SEE_MORE_RIGHT_MARGIN_PX = PILL_X_GAP_PX
const SEE_MORE_LEFT_MARGIN_PX = 0

export const handleVisibility = ({
  setVisibility,
  leftoverWidth,
  seeMoreWidth,
  pillWidths,
  pillGap,
  mustShowSeeMoreMenu
}: {
  setVisibility: (v: VisibilityState) => void
  leftoverWidth: number | null
  pillWidths: (number | null)[] | null
  seeMoreWidth: number
  pillGap: number
  mustShowSeeMoreMenu: boolean
}): void => {
  if (leftoverWidth === null || pillWidths === null) {
    return
  }

  const fitToWidth = (maxWidth: number) => {
    let visibleCount = 0
    let currentWidth = 0
    let lastValidWidth = 0
    for (const pillWidth of pillWidths) {
      currentWidth += (pillWidth ?? 0) + pillGap
      if (currentWidth <= maxWidth) {
        lastValidWidth = currentWidth
        visibleCount += 1
      } else {
        break
      }
    }
    return { visibleCount, lastValidWidth }
  }

  const fits = fitToWidth(leftoverWidth)

  const seeMoreWillBePresent =
    fits.visibleCount < pillWidths.length || mustShowSeeMoreMenu

  // Check if the appearance of "See more" would cause overflow
  if (seeMoreWillBePresent) {
    const maybeFitsLess = fitToWidth(leftoverWidth - seeMoreWidth)
    if (maybeFitsLess.visibleCount < fits.visibleCount) {
      return setVisibility({
        width: maybeFitsLess.lastValidWidth,
        visibleCount: maybeFitsLess.visibleCount
      })
    }
  }

  return setVisibility({
    width: fits.lastValidWidth,
    visibleCount: fits.visibleCount
  })
}

const getElementWidthOrNull = <
  T extends Pick<HTMLElement, 'getBoundingClientRect'>
>(
  element: T | null
) => (element === null ? null : element.getBoundingClientRect().width)

type VisibilityState = {
  width: number
  visibleCount: number
}

type ElementAccessor = (
  filtersBarElement: HTMLElement | null
) => HTMLElement | null | undefined

/**
 * The accessors are paths to other elements that FiltersBar needs to measure:
 * they depend on the structure of the parent and are thus passed as props.
 * Passing these with refs would be more reactive, but the main layout effect
 * didn't trigger then as expected.
 */
interface FiltersBarProps {
  accessors: {
    topBar: ElementAccessor
    leftSection: ElementAccessor
    rightSection: ElementAccessor
  }
}

const canShowClearAllAction = ({
  filters
}: Pick<DashboardQuery, 'filters'>): boolean => filters.length >= 2

const canShowSaveAsSegmentAction = ({
  filters,
  isEditingSegment
}: Pick<DashboardQuery, 'filters'> & { isEditingSegment: boolean }): boolean =>
  filters.length >= 1 && !filters.some(isSegmentFilter) && !isEditingSegment

export const FiltersBar = ({ accessors }: FiltersBarProps) => {
  const containerRef = useRef<HTMLDivElement>(null)
  const pillsRef = useRef<HTMLDivElement>(null)
  const [visibility, setVisibility] = useState<null | VisibilityState>(null)
  const { query, expandedSegment } = useQueryContext()

  const showingClearAll = canShowClearAllAction({ filters: query.filters })
  const showingSaveAsSegment = canShowSaveAsSegmentAction({
    filters: query.filters,
    isEditingSegment: !!expandedSegment
  })

  const mustShowSeeMoreMenu = showingClearAll || showingSaveAsSegment

  useLayoutEffect(() => {
    const topBar = accessors.topBar(containerRef.current)
    const leftSection = accessors.leftSection(containerRef.current)
    const rightSection = accessors.rightSection(containerRef.current)

    const resizeObserver = new ResizeObserver(() => {
      const pillWidths = pillsRef.current
        ? Array.from(pillsRef.current.children).map((el) =>
            getElementWidthOrNull(el)
          )
        : null
      handleVisibility({
        setVisibility,
        pillWidths,
        pillGap: PILL_X_GAP_PX,
        leftoverWidth:
          topBar && leftSection && rightSection
            ? getElementWidthOrNull(topBar)! -
              getElementWidthOrNull(leftSection)! -
              getElementWidthOrNull(rightSection)! -
              BUFFER_LEFT_PX -
              BUFFER_RIGHT_PX
            : null,
        seeMoreWidth:
          SEE_MORE_LEFT_MARGIN_PX +
          SEE_MORE_WIDTH_PX +
          SEE_MORE_RIGHT_MARGIN_PX,
        mustShowSeeMoreMenu
      })
    })

    if (containerRef.current && topBar) {
      resizeObserver.observe(topBar)
    }

    return () => {
      resizeObserver.disconnect()
    }
  }, [accessors, query.filters, mustShowSeeMoreMenu])

  if (!query.filters.length) {
    // functions as spacer between elements.leftSection and elements.rightSection
    return <div className="w-4" />
  }

  return (
    <div
      style={{ paddingRight: BUFFER_RIGHT_PX, paddingLeft: BUFFER_LEFT_PX }}
      className={classNames(
        'flex w-full items-center',
        visibility === null && 'invisible' // hide until we've calculated the positions
      )}
      ref={containerRef}
    >
      <div className="flex items-center">
        <AppliedFilterPillsList
          ref={pillsRef}
          direction="horizontal"
          slice={{
            type: 'invisible-outside',
            start: 0,
            end: visibility?.visibleCount
          }}
          className="overflow-hidden"
          style={{ width: visibility?.width ?? 0 }}
        />
      </div>
      {visibility !== null &&
        (query.filters.length !== visibility.visibleCount ||
          mustShowSeeMoreMenu) && (
          <SeeMoreMenu
            className="md:relative"
            filtersCount={query.filters.length}
            visibleFiltersCount={visibility.visibleCount}
          >
            {showingClearAll && <ClearAction />}
            {showingSaveAsSegment && <SaveAsSegmentAction />}
          </SeeMoreMenu>
        )}
    </div>
  )
}

const SeeMoreMenu = ({
  className,
  filtersCount,
  visibleFiltersCount,
  children
}: {
  className?: string
  filtersCount: number
  visibleFiltersCount: number
  children: ReactNode
}) => {
  const seeMoreRef = useRef<HTMLButtonElement>(null)
  const filtersInMenuCount = filtersCount - visibleFiltersCount

  const title =
    filtersInMenuCount === 1
      ? 'See 1 more filter and actions'
      : filtersInMenuCount > 1
        ? `See ${filtersInMenuCount} more filters and actions`
        : 'See actions'

  return (
    <Popover className={className}>
      <BlurMenuButtonOnEscape targetRef={seeMoreRef} />
      <Popover.Button
        title={title}
        ref={seeMoreRef}
        className={classNames(
          popover.toggleButton.classNames.rounded,
          popover.toggleButton.classNames.shadow,
          'justify-center'
        )}
        style={{
          height: SEE_MORE_WIDTH_PX,
          width: SEE_MORE_WIDTH_PX,
          marginLeft: SEE_MORE_LEFT_MARGIN_PX,
          marginRight: SEE_MORE_RIGHT_MARGIN_PX
        }}
      >
        <EllipsisHorizontalIcon className="block h-5 w-5" />
      </Popover.Button>
      <Transition
        {...popover.transition.props}
        className={classNames(
          'mt-2',
          popover.transition.classNames.fullwidth,
          'md:right-auto'
        )}
      >
        <Popover.Panel
          className={classNames(
            popover.panel.classNames.roundedSheet,
            'flex flex-col p-4 gap-y-2'
          )}
        >
          {filtersCount !== visibleFiltersCount && (
            <AppliedFilterPillsList
              direction="vertical"
              slice={{
                type: 'no-render-outside',
                start: visibleFiltersCount
              }}
            />
          )}
          {children}
        </Popover.Panel>
      </Transition>
    </Popover>
  )
}

const ClearAction = () => (
  <AppNavigationLink
    className={classNames(
      'button flex self-start h-9 !px-3 !bg-red-500 dark:!bg-red-500 hover:!bg-red-600 dark:hover:!bg-red-700 whitespace-nowrap'
    )}
    search={(search) => ({
      ...search,
      filters: null,
      labels: null
    })}
  >
    Clear all filters
  </AppNavigationLink>
)

const SaveAsSegmentAction = () => {
  const { setModal } = useRoutelessModalsContext()

  return (
    <AppNavigationLink
      className={classNames(
        'button flex self-start h-9 !px-3 whitespace-nowrap'
      )}
      search={(s) => s}
      onClick={() => setModal('create')}
      state={{ expandedSegment: null }}
    >
      Save as segment
    </AppNavigationLink>
  )
}
