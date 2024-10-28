/** @format */

import { EllipsisHorizontalIcon, XMarkIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import React, { useRef, useState, useLayoutEffect, useEffect } from 'react'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import { useOnClickOutside } from '../util/use-on-click-outside'
import {
  DropdownMenuWrapper,
  ToggleDropdownButton
} from '../components/dropdown'
import { FilterPillsList, PILL_X_GAP } from './filter-pills-list'
import { useQueryContext } from '../query-context'

const SEE_MORE_GAP_PX = 16
const SEE_MORE_WIDTH_PX = 36

export const handleVisibility = ({
  setVisibility,
  topBarWidth,
  actionsWidth,
  seeMorePresent,
  seeMoreWidth,
  pillWidths,
  pillGap
}: {
  setVisibility: (v: VisibilityState) => void
  topBarWidth: number | null
  actionsWidth: number | null
  pillWidths: (number | null)[] | null
  seeMorePresent: boolean
  seeMoreWidth: number
  pillGap: number
}): void => {
  if (topBarWidth === null || actionsWidth === null || pillWidths === null) {
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

  const fits = fitToWidth(topBarWidth - actionsWidth)

  // Check if possible to fit one more if "See more" is removed
  if (seeMorePresent && fits.visibleCount === pillWidths.length - 1) {
    const maybeFitsMore = fitToWidth(topBarWidth - actionsWidth + seeMoreWidth)
    if (maybeFitsMore.visibleCount === pillWidths.length) {
      return setVisibility({
        width: maybeFitsMore.lastValidWidth,
        visibleCount: maybeFitsMore.visibleCount
      })
    }
  }

  // Check if the appearance of "See more" would cause overflow
  if (!seeMorePresent && fits.visibleCount < pillWidths.length) {
    const maybeFitsLess = fitToWidth(topBarWidth - actionsWidth - seeMoreWidth)
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

const getElementWidthOrNull = <T extends HTMLElement>(element: T | null) =>
  element === null ? null : element.getBoundingClientRect().width

type VisibilityState = {
  width: number
  visibleCount: number
}

export const FiltersBar = () => {
  const containerRef = useRef<HTMLDivElement>(null)
  const pillsRef = useRef<HTMLDivElement>(null)
  const actionsRef = useRef<HTMLDivElement>(null)
  const seeMoreRef = useRef<HTMLDivElement>(null)
  const [visibility, setVisibility] = useState<null | VisibilityState>(null)
  const { query } = useQueryContext()

  const [opened, setOpened] = useState(false)

  useEffect(() => {
    if (visibility?.visibleCount === query.filters.length) {
      setOpened(false)
    }
  }, [visibility?.visibleCount, query.filters.length])

  useOnClickOutside({
    ref: seeMoreRef,
    active: opened,
    handler: () => setOpened(false)
  })

  useLayoutEffect(() => {
    const resizeObserver = new ResizeObserver((_entries) => {
      const pillWidths = pillsRef.current
        ? Array.from(pillsRef.current.children).map((el) =>
            getElementWidthOrNull(el as HTMLElement)
          )
        : null
      handleVisibility({
        setVisibility,
        pillWidths,
        pillGap: PILL_X_GAP,
        topBarWidth: getElementWidthOrNull(containerRef.current),
        actionsWidth: getElementWidthOrNull(actionsRef.current),
        seeMorePresent: !!seeMoreRef.current,
        seeMoreWidth: SEE_MORE_WIDTH_PX + SEE_MORE_GAP_PX
      })
    })

    if (containerRef.current) {
      resizeObserver.observe(containerRef.current)
    }

    return () => {
      resizeObserver.disconnect()
    }
  }, [query.filters])

  if (!query.filters.length) {
    return null
  }

  return (
    <div
      className={classNames(
        'flex w-full mt-4',
        visibility === null && 'invisible' // hide until we've calculated the positions
      )}
      ref={containerRef}
    >
      <FilterPillsList
        ref={pillsRef}
        direction="horizontal"
        slice={{
          type: 'hide-outside',
          start: 0,
          end: visibility?.visibleCount
        }}
        className="pb-1 overflow-hidden"
        style={{ width: visibility?.width ?? '100%' }}
      />
      <div className="flex items-center gap-x-4 pb-1" ref={actionsRef}>
        {visibility !== null &&
          visibility.visibleCount !== query.filters.length && (
            <ToggleDropdownButton
              className={classNames('w-9 md:relative')}
              ref={seeMoreRef}
              dropdownContainerProps={{
                ['title']: opened
                  ? 'Hide rest of the filters'
                  : 'Show rest of the filters',
                ['aria-controls']: 'more-filters-menu',
                ['aria-expanded']: opened
              }}
              onClick={() => setOpened((opened) => !opened)}
              currentOption={
                <EllipsisHorizontalIcon className="h-full w-full" />
              }
            >
              {opened && typeof visibility.visibleCount === 'number' ? (
                <DropdownMenuWrapper
                  id={'more-filters-menu'}
                  className="md:left-auto md:w-auto"
                  innerContainerClassName="p-4"
                >
                  <FilterPillsList
                    direction="vertical"
                    slice={{
                      type: 'no-render-outside',
                      start: visibility.visibleCount
                    }}
                  />
                </DropdownMenuWrapper>
              ) : null}
            </ToggleDropdownButton>
          )}
        <ClearAction />
      </div>
    </div>
  )
}

export const ClearAction = () => (
  <AppNavigationLink
    title="Clear all filters"
    className="w-9 text-gray-500 hover:text-indigo-700 dark:hover:text-indigo-500 flex items-center justify-center"
    search={(search) => ({
      ...search,
      filters: null,
      labels: null
    })}
  >
    <XMarkIcon className="w-4 h-4" />
  </AppNavigationLink>
)
