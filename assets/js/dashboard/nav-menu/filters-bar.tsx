/** @format */

import { EllipsisHorizontalIcon } from '@heroicons/react/24/solid'
import classNames from 'classnames'
import React, { useRef, useState, useLayoutEffect } from 'react'
import { AppliedFilterPillsList, PILL_X_GAP } from './filter-pills-list'
import { useQueryContext } from '../query-context'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import { BUFFER_FOR_SHADOW_PX } from './filter-pill'
import { Popover, Transition } from '@headlessui/react'
import { popover } from '../components/popover'
import { BlurMenuButtonOnEscape } from '../keybinding'

const BUFFER_RIGHT_PX = 16 - BUFFER_FOR_SHADOW_PX - PILL_X_GAP
const BUFFER_LEFT_PX = 16 - BUFFER_FOR_SHADOW_PX
const SEE_MORE_WIDTH_PX = 36
const SEE_MORE_RIGHT_MARGIN_PX = BUFFER_FOR_SHADOW_PX + PILL_X_GAP
const SEE_MORE_LEFT_MARGIN_PX = BUFFER_FOR_SHADOW_PX

export const handleVisibility = ({
  setVisibility,
  leftoverWidth,
  seeMoreWidth,
  pillWidths,
  pillGap
}: {
  setVisibility: (v: VisibilityState) => void
  leftoverWidth: number | null
  pillWidths: (number | null)[] | null
  seeMoreWidth: number
  pillGap: number
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
    fits.visibleCount < pillWidths.length || pillWidths.length > 1

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

export const FiltersBar = ({ accessors }: FiltersBarProps) => {
  const containerRef = useRef<HTMLDivElement>(null)
  const pillsRef = useRef<HTMLDivElement>(null)
  const [visibility, setVisibility] = useState<null | VisibilityState>(null)
  const { query } = useQueryContext()
  const seeMoreRef = useRef<HTMLButtonElement>(null)

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
        pillGap: PILL_X_GAP,
        leftoverWidth:
          topBar && leftSection && rightSection
            ? getElementWidthOrNull(topBar)! -
              getElementWidthOrNull(leftSection)! -
              getElementWidthOrNull(rightSection)! -
              BUFFER_LEFT_PX -
              BUFFER_RIGHT_PX
            : null,
        seeMoreWidth:
          SEE_MORE_LEFT_MARGIN_PX + SEE_MORE_WIDTH_PX + SEE_MORE_RIGHT_MARGIN_PX
      })
    })

    if (containerRef.current && topBar) {
      resizeObserver.observe(topBar)
    }

    return () => {
      resizeObserver.disconnect()
    }
  }, [accessors, query.filters])

  if (!query.filters.length) {
    // functions as spacer between elements.leftSection and elements.rightSection
    return <div className="w-4" />
  }

  const canClear = query.filters.length > 1

  return (
    <div
      style={{ paddingRight: BUFFER_RIGHT_PX, paddingLeft: BUFFER_LEFT_PX }}
      className={classNames(
        'flex w-full items-center',
        visibility === null && 'invisible' // hide until we've calculated the positions
      )}
      ref={containerRef}
    >
      <div
        style={{
          marginTop: -BUFFER_FOR_SHADOW_PX,
          marginBottom: -BUFFER_FOR_SHADOW_PX
        }}
        className="flex items-center"
      >
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
        (query.filters.length !== visibility.visibleCount || canClear) && (
          <Popover className="md:relative">
            <BlurMenuButtonOnEscape targetRef={seeMoreRef} />
            <Popover.Button
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
                {query.filters.length !== visibility.visibleCount && (
                  <AppliedFilterPillsList
                    style={{ margin: -BUFFER_FOR_SHADOW_PX }}
                    direction="vertical"
                    slice={{
                      type: 'no-render-outside',
                      start: visibility.visibleCount
                    }}
                  />
                )}
                {canClear && <ClearAction />}
              </Popover.Panel>
            </Transition>
          </Popover>
        )}
    </div>
  )
}

const ClearAction = () => (
  <AppNavigationLink
    title="Clear all filters"
    className={classNames(
      'self-start button h-9 !px-3 !py-2 flex !bg-red-500 dark:!bg-red-500 hover:!bg-red-600 dark:hover:!bg-red-700 whitespace-nowrap'
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
