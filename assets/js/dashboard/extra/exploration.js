import React, { useState, useEffect, useLayoutEffect, useRef } from 'react'
import * as api from '../api'
import * as url from '../util/url'
import { Tooltip } from '../util/tooltip'
import { useDebounce } from '../custom-hooks'
import { useSiteContext } from '../site-context'
import { useDashboardStateContext } from '../dashboard-state-context'
import {
  numberShortFormatter,
  numberLongFormatter
} from '../util/number-formatter'
import { RefreshIcon } from '../components/icons'
import { ChevronUpDownIcon } from '@heroicons/react/20/solid'
import { popover } from '../components/popover'

const PAGE_FILTER_KEYS = ['page', 'entry_page', 'exit_page']
const EXPLORATION_DIRECTIONS = {
  FORWARD: 'forward',
  BACKWARD: 'backward'
}

function stateWithApplicableFilters(dashboardState, steps) {
  if (steps.length === 0) {
    return dashboardState
  }

  return {
    ...dashboardState,
    filters: dashboardState.filters.filter(
      ([_op, key]) => !PAGE_FILTER_KEYS.includes(key)
    )
  }
}

function toJourney(steps) {
  return steps.map((s) => ({
    name: s.name,
    pathname: s.pathname,
    includes_subpaths: s.includes_subpaths,
    subpaths_count: s.subpaths_count
  }))
}

function fetchNextWithFunnel(
  site,
  dashboardState,
  steps,
  filter,
  direction,
  includeFunnel
) {
  const stateToUse = stateWithApplicableFilters(dashboardState, steps)
  const journey = toJourney(steps)

  return api.post(
    url.apiPath(site, '/exploration/next-with-funnel'),
    stateToUse,
    {
      journey: JSON.stringify(journey),
      search_term: filter,
      direction,
      include_funnel: includeFunnel
    }
  )
}

function fetchInterestingFunnel(site, dashboardState) {
  return api.post(
    url.apiPath(site, '/exploration/interesting-funnel'),
    dashboardState,
    { max_steps: 2, max_candidates: 6 }
  )
}

function isSameStep(step, otherStep) {
  return (
    step.name === otherStep.name &&
    step.pathname === otherStep.pathname &&
    step.includes_subpaths === otherStep.includes_subpaths
  )
}

function truncateFrozenResultsAtIndex(frozenResults, fromIndex) {
  const next = {}
  Object.keys(frozenResults).forEach((key) => {
    const idx = Number(key)
    if (idx < fromIndex) next[idx] = frozenResults[key]
  })
  return next
}

function DirectionDropdown({ direction, onDirectionChange }) {
  const [open, setOpen] = useState(false)
  const ref = useRef(null)

  useEffect(() => {
    if (!open) return
    function handleClickOutside(e) {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false)
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [open])

  const label =
    direction === EXPLORATION_DIRECTIONS.FORWARD
      ? 'Starting point'
      : 'End point'

  return (
    <div ref={ref} className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex items-center gap-0.5 text-xs font-semibold text-gray-800 dark:text-gray-200 hover:text-gray-700 dark:hover:text-gray-200"
      >
        {label}
        <ChevronUpDownIcon className="size-3.5 shrink-0" />
      </button>
      {open && (
        <div
          className={`absolute -left-1 top-full mt-1 z-10 min-w-40 ${popover.panel.classNames.roundedSheet}`}
        >
          {[
            [EXPLORATION_DIRECTIONS.FORWARD, 'Starting point'],
            [EXPLORATION_DIRECTIONS.BACKWARD, 'End point']
          ].map(([value, optionLabel]) => (
            <button
              key={value}
              onClick={() => {
                onDirectionChange(value)
                setOpen(false)
              }}
              className={`w-full text-left text-sm rounded-md ${popover.items.classNames.navigationLink} ${popover.items.classNames.hoverLink} ${
                direction === value
                  ? popover.items.classNames.selectedOption
                  : ''
              }`}
              data-selected={direction === value}
            >
              {optionLabel}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

function PathConnectors({ scrollRef, steps }) {
  const [svgData, setSvgData] = useState({
    paths: [],
    width: 0,
    height: 0,
    clipY: 0,
    clipHeight: 0
  })

  useLayoutEffect(() => {
    const container = scrollRef.current
    if (!container || steps.length < 2) {
      setSvgData({ paths: [], width: 0, height: 0, clipY: 0, clipHeight: 0 })
      return
    }

    function recalculate() {
      const c = scrollRef.current
      if (!c) return
      const containerRect = c.getBoundingClientRect()
      const newPaths = []

      for (let i = 0; i < steps.length - 1; i++) {
        const cardA = c.querySelector(`[data-exploration-step="${i}"]`)
        const cardB = c.querySelector(`[data-exploration-step="${i + 1}"]`)
        const colA = c.querySelector(`[data-exploration-column="${i}"]`)
        const colB = c.querySelector(`[data-exploration-column="${i + 1}"]`)
        if (!cardA || !cardB || !colA || !colB) continue

        const rColA = colA.getBoundingClientRect()
        const rColB = colB.getBoundingClientRect()
        const rCardA = cardA.getBoundingClientRect()
        const rCardB = cardB.getBoundingClientRect()

        const x1 = rColA.right - containerRect.left + c.scrollLeft
        const y1 = (rCardA.top + rCardA.bottom) / 2 - containerRect.top
        const x2 = rColB.left - containerRect.left + c.scrollLeft
        const y2 = (rCardB.top + rCardB.bottom) / 2 - containerRect.top
        const mx = (x1 + x2) / 2
        const dy = y2 - y1
        const r = Math.min(10, Math.abs(dy) / 2)

        const d =
          Math.abs(dy) < 1
            ? `M ${x1} ${y1} H ${x2}`
            : dy > 0
              ? `M ${x1} ${y1} H ${mx - r} A ${r} ${r} 0 0 1 ${mx} ${y1 + r} V ${y2 - r} A ${r} ${r} 0 0 0 ${mx + r} ${y2} H ${x2}`
              : `M ${x1} ${y1} H ${mx - r} A ${r} ${r} 0 0 0 ${mx} ${y1 - r} V ${y2 + r} A ${r} ${r} 0 0 1 ${mx + r} ${y2} H ${x2}`

        newPaths.push(d)
      }

      const firstList = c.querySelector('[data-exploration-list]')
      const listRect = firstList ? firstList.getBoundingClientRect() : null
      const clipY = listRect ? listRect.top - containerRect.top : 0
      const clipHeight = listRect ? listRect.height : c.clientHeight

      setSvgData({
        paths: newPaths,
        width: c.scrollWidth,
        height: c.clientHeight,
        clipY,
        clipHeight
      })
    }

    recalculate()

    const observer = new ResizeObserver(recalculate)
    observer.observe(container)
    window.addEventListener('resize', recalculate)

    const lists = Array.from(
      container.querySelectorAll('[data-exploration-list]')
    )
    lists.forEach((list) => list.addEventListener('scroll', recalculate))

    return () => {
      observer.disconnect()
      window.removeEventListener('resize', recalculate)
      lists.forEach((list) => list.removeEventListener('scroll', recalculate))
    }
  }, [steps, scrollRef])

  if (svgData.paths.length === 0) return null

  return (
    <svg
      className="absolute inset-0 pointer-events-none overflow-visible"
      width={svgData.width}
      height={svgData.height}
    >
      <defs>
        <clipPath id="exploration-list-clip">
          <rect
            x="0"
            y={svgData.clipY}
            width={svgData.width}
            height={svgData.clipHeight}
          />
        </clipPath>
      </defs>
      {svgData.paths.map((d, i) => (
        <path
          key={i}
          d={d}
          fill="none"
          clipPath="url(#exploration-list-clip)"
          className="stroke-indigo-200/80 dark:stroke-indigo-800"
          strokeWidth="1.5"
        />
      ))}
    </svg>
  )
}

function ExplorationColumn({
  header,
  // null means column should not be rendered (no preceding step selected)
  active,
  results,
  loading,
  maxVisitors,
  selected,
  selectedVisitors,
  selectedConversionRate,
  onSelect,
  onFilterChange,
  filter,
  direction,
  onDirectionChange,
  headerConversionRate,
  colIndex
}) {
  const debouncedOnFilterChange = useDebounce((event) =>
    onFilterChange(event.target.value)
  )

  const stepMaxVisitors = maxVisitors || results[0]?.visitors

  // When a step is selected we keep showing the full candidate list so the
  // user can quickly switch to another option. If we don't have the candidate
  // list (e.g. preloaded journey), fall back to a synthetic single item built
  // from the funnel data so the column still renders the selected step.
  const listItems =
    selected && results.length === 0
      ? [{ step: selected, visitors: selectedVisitors ?? 0 }]
      : results.slice(0, 10)

  return (
    <div
      data-exploration-column={colIndex}
      className="min-w-80 flex-1 bg-gray-50 dark:bg-gray-800 rounded-lg overflow-hidden"
    >
      <div className="h-[42px] pt-2 pl-4 pr-1.5 flex items-center justify-between">
        {onDirectionChange ? (
          <DirectionDropdown
            direction={direction}
            onDirectionChange={onDirectionChange}
          />
        ) : (
          <span className="shrink-0 text-xs font-semibold text-gray-800 dark:text-gray-200">
            {header}
          </span>
        )}
        {!selected && active && (
          <input
            data-testid="search-input"
            type="text"
            defaultValue={filter}
            placeholder="Search"
            onChange={debouncedOnFilterChange}
            className="peer max-w-48 w-full text-xs dark:text-gray-100 block border-gray-300 dark:border-gray-750 rounded-md dark:bg-gray-750 dark:placeholder:text-gray-400 focus:outline-none focus:ring-3 focus:ring-indigo-500/20 dark:focus:ring-indigo-500/25 focus:border-indigo-500"
          />
        )}
        {headerConversionRate && (
          <span className="shrink-0 text-xs font-semibold text-gray-800 dark:text-gray-200">
            {headerConversionRate}
          </span>
        )}
      </div>

      {loading ? (
        <div className="h-110 flex items-center justify-center">
          <div className="mx-auto loading pt-4">
            <div></div>
          </div>
        </div>
      ) : results.length === 0 && !selected ? (
        <div className="h-110 flex items-center justify-center text-sm text-gray-400 dark:text-gray-500">
          {!active ? 'Select an event to continue' : 'No data'}
        </div>
      ) : (
        <ul
          data-exploration-list
          className="flex flex-col gap-y-2 p-2 h-110 overflow-y-auto [scrollbar-width:thin] [scrollbar-color:theme(colors.gray.300)_transparent] dark:[scrollbar-color:theme(colors.gray.600)_transparent]"
        >
          {listItems.map(({ step, visitors }) => {
            const isSelected = !!selected && isSameStep(step, selected)
            const isDimmed = !!selected && !isSelected
            const isCustomEvent = step.name !== 'pageview'
            const visitorsToShow =
              isSelected && selectedVisitors !== null
                ? selectedVisitors
                : visitors
            const barWidth =
              isSelected && selectedConversionRate !== null
                ? selectedConversionRate
                : Math.round((visitors / stepMaxVisitors) * 100)
            const label = step.includes_subpaths
              ? `${step.label}… (${step.subpaths_count} pages)`
              : step.label

            return (
              <li key={label}>
                <button
                  data-exploration-step={isSelected ? colIndex : undefined}
                  className={`group w-full border text-left px-4 py-3 text-sm rounded-md focus:outline-none ${
                    isSelected
                      ? isCustomEvent
                        ? 'bg-red-50/80 dark:bg-gray-750 border-red-100 dark:border-transparent'
                        : 'bg-indigo-50/80 dark:bg-gray-750 border-indigo-100 dark:border-transparent'
                      : 'bg-white border-gray-150 dark:border-gray-750'
                  }`}
                  onClick={() => onSelect(isSelected ? null : step)}
                >
                  <div className="flex items-center justify-between gap-2 mb-1">
                    <span
                      className={`truncate ${
                        isDimmed
                          ? 'text-gray-500 dark:text-gray-400'
                          : 'text-gray-800 dark:text-gray-200'
                      }`}
                      title={step.label}
                    >
                      {step.name === 'pageview' ? step.pathname : step.label}
                    </span>
                    <span
                      className={`shrink-0 font-medium ${
                        isDimmed
                          ? 'text-gray-500 dark:text-gray-400'
                          : 'text-gray-800 dark:text-gray-200'
                      }`}
                    >
                      <Tooltip info={numberLongFormatter(visitorsToShow)}>
                        {numberShortFormatter(visitorsToShow)}
                      </Tooltip>
                    </span>
                  </div>
                  <div
                    className={`h-1 rounded-full overflow-hidden ${
                      isSelected
                        ? isCustomEvent
                          ? 'bg-red-200/70 dark:bg-gray-700'
                          : 'bg-indigo-200/70 dark:bg-gray-700'
                        : 'bg-gray-150 dark:bg-gray-700/50'
                    }`}
                  >
                    <div
                      className={`h-full rounded-full transition-[width] ease-in-out ${
                        isSelected
                          ? isCustomEvent
                            ? 'bg-red-400 dark:bg-white'
                            : 'bg-indigo-500 dark:bg-white'
                          : isCustomEvent
                            ? 'bg-red-300 dark:bg-gray-500 group-hover:bg-red-400 dark:group-hover:bg-white'
                            : 'bg-indigo-300 dark:bg-gray-500 group-hover:bg-indigo-400 dark:group-hover:bg-white'
                      }`}
                      style={{ width: `${barWidth}%` }}
                    />
                  </div>
                </button>
              </li>
            )
          })}
        </ul>
      )}
    </div>
  )
}

function columnHeader(index, direction) {
  if (index === 0) {
    return direction === EXPLORATION_DIRECTIONS.BACKWARD
      ? 'End point'
      : 'Starting point'
  }

  return `${index} step${index === 1 ? '' : 's'} ${
    direction === EXPLORATION_DIRECTIONS.BACKWARD ? 'before' : 'after'
  }`
}

export function FunnelExploration() {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const [steps, setSteps] = useState([])
  const [direction, setDirection] = useState(EXPLORATION_DIRECTIONS.FORWARD)
  const [funnel, setFunnel] = useState([])
  // Results for the active (last, unselected) column
  const [activeColumnResults, setActiveColumnResults] = useState([])
  const [activeColumnFilter, setActiveColumnFilter] = useState('')
  const [activeColumnLoading, setActiveColumnLoading] = useState(false)
  // Snapshot of candidate results at the moment a step was selected, kept per
  // column index so previously-active columns can keep showing their full
  // candidate list (with the selected option highlighted) instead of
  // collapsing to a single item.
  const [frozenColumnResults, setFrozenColumnResults] = useState({})
  // Initial visitor/bar data for a newly selected step, held until
  // real funnel response arrives. Prevents from flashing "0 visitors"
  // during the loading window.
  const [provisionalFunnelEntries, setProvisionalFunnelEntries] = useState({})
  // Tracks the steps/direction/dashboardState values from the previous effect
  // run so we can tell whether the journey changed (needs funnel) or only the
  // search filter changed (next steps only, no funnel).
  const prevStepsRef = useRef(steps)
  const prevDirectionRef = useRef(direction)
  const prevDashboardStateRef = useRef(dashboardState)
  const preloadFiredRef = useRef(false)
  const funnelFromPreloadRef = useRef(false)
  // Bumped whenever the user actively changes the journey or direction.
  // Used to discard stale preload-driven candidate fetches that resolve
  // after the user has already navigated away from the preloaded prefix.
  const journeyVersionRef = useRef(0)

  function handleSelect(columnIndex, selected) {
    journeyVersionRef.current++
    // Reset the active-column filter whenever the journey changes
    setActiveColumnFilter('')

    if (selected === null) {
      setProvisionalFunnelEntries({})
      setActiveColumnResults([])
      setActiveColumnLoading(true)
      setFrozenColumnResults((prev) =>
        truncateFrozenResultsAtIndex(prev, columnIndex)
      )
      setSteps(steps.slice(0, columnIndex))
    } else {
      // Snapshot the clicked step's visitor count from the current results so
      // the column can display a sensible value immediately, before the funnel
      // API response arrives. The bar width is computed relative to the first
      // step's visitor count (same baseline the real funnel uses).
      const sourceResults =
        columnIndex === steps.length
          ? activeColumnResults
          : frozenColumnResults[columnIndex] || []
      const match = sourceResults.find(({ step }) => isSameStep(step, selected))
      if (match) {
        const firstStepVisitors = funnel[0]?.visitors ?? match.visitors
        const conversionRate = Math.round(
          (match.visitors / firstStepVisitors) * 100
        )
        setProvisionalFunnelEntries({
          [columnIndex]: {
            visitors: match.visitors,
            conversion_rate: conversionRate
          }
        })
      } else {
        setProvisionalFunnelEntries({})
      }
      setFrozenColumnResults((prev) => {
        if (columnIndex === steps.length) {
          // Selecting from the active column: freeze its current results so
          // they remain visible in the now-selected column.
          return {
            ...truncateFrozenResultsAtIndex(prev, columnIndex),
            [columnIndex]: activeColumnResults
          }
        }
        // Selecting from a previously-frozen column: keep its frozen results
        // (the user is browsing them) but drop anything beyond, since the
        // journey downstream just changed.
        return truncateFrozenResultsAtIndex(prev, columnIndex + 1)
      })
      setActiveColumnResults([])
      setActiveColumnLoading(true)
      setSteps([...steps.slice(0, columnIndex), selected])
    }
  }

  function handleReset() {
    journeyVersionRef.current++
    setSteps([])
    setFunnel([])
    setActiveColumnResults([])
    setActiveColumnFilter('')
    setProvisionalFunnelEntries({})
    setFrozenColumnResults({})
  }

  function handleDirectionSelect(nextDirection) {
    if (nextDirection === direction) return

    journeyVersionRef.current++
    setDirection(nextDirection)
    setSteps([])
    setFunnel([])
    setActiveColumnResults([])
    setActiveColumnFilter('')
    setProvisionalFunnelEntries({})
    setFrozenColumnResults({})
  }

  // Frozen candidate lists were fetched against a specific site +
  // dashboard filter context. When either changes the cached candidates
  // become stale, so drop them and invalidate any in-flight preload
  // backfills. We skip the initial run so we don't clobber the freshly
  // populated state on mount.
  const initialFilterContextRef = useRef(true)
  useEffect(() => {
    if (initialFilterContextRef.current) {
      initialFilterContextRef.current = false
      return
    }
    journeyVersionRef.current++
    setFrozenColumnResults({})
  }, [site, dashboardState])

  // On first render fire the interesting-funnel preload and skip the normal
  // next-with-funnel fetch. Once the preload resolves it sets steps
  // and funnel, which re-triggers this effect for the next-step candidates fetch.
  //
  // On subsequent renders (via user interaction) fetch next steps and,
  // if the journey changed, also refetch the funnel.
  useEffect(() => {
    const journeyChanged =
      prevStepsRef.current !== steps ||
      prevDirectionRef.current !== direction ||
      prevDashboardStateRef.current !== dashboardState

    prevStepsRef.current = steps
    prevDirectionRef.current = direction
    prevDashboardStateRef.current = dashboardState

    let cancelled = false

    if (!preloadFiredRef.current) {
      preloadFiredRef.current = true
      setActiveColumnLoading(true)

      fetchInterestingFunnel(site, dashboardState)
        .then((response) => {
          if (cancelled) return
          if (response && response.length > 0) {
            funnelFromPreloadRef.current = true
            const preloadedSteps = response.map(({ step }) => step)
            setSteps(preloadedSteps)
            setFunnel(response)
            // Backfill candidate lists for each preloaded (selected) column
            // so the user can immediately switch options without first
            // having to clear and re-search. We capture the current journey
            // version so any of these fetches that resolve after the user
            // has navigated away can be safely ignored.
            const journeyVersion = journeyVersionRef.current
            preloadedSteps.forEach((_, idx) => {
              const prefix = preloadedSteps.slice(0, idx)
              fetchNextWithFunnel(
                site,
                dashboardState,
                prefix,
                '',
                direction,
                false
              )
                .then((r) => {
                  if (journeyVersionRef.current !== journeyVersion) return
                  setFrozenColumnResults((prev) => ({
                    ...prev,
                    [idx]: r?.next || []
                  }))
                })
                .catch(() => {})
            })
          } else {
            // Nothing to preload, fall back to a plain next-steps fetch
            fetchNextWithFunnel(site, dashboardState, [], '', direction, false)
              .then((r) => {
                if (!cancelled) setActiveColumnResults(r?.next || [])
              })
              .catch(() => {
                if (!cancelled) setActiveColumnResults([])
              })
              .finally(() => {
                if (!cancelled) setActiveColumnLoading(false)
              })
          }
        })
        .catch(() => {
          if (cancelled) return
          fetchNextWithFunnel(site, dashboardState, [], '', direction, false)
            .then((r) => {
              if (!cancelled) setActiveColumnResults(r?.next || [])
            })
            .catch(() => {
              if (!cancelled) setActiveColumnResults([])
            })
            .finally(() => {
              if (!cancelled) setActiveColumnLoading(false)
            })
        })

      return () => {
        cancelled = true
      }
    }

    setActiveColumnLoading(true)
    setActiveColumnResults([])

    const funnelAlreadyLoaded = funnelFromPreloadRef.current
    funnelFromPreloadRef.current = false

    const includeFunnel =
      journeyChanged && steps.length > 0 && !funnelAlreadyLoaded

    if (journeyChanged && steps.length === 0) {
      setFunnel([])
    }

    fetchNextWithFunnel(
      site,
      dashboardState,
      steps,
      activeColumnFilter,
      direction,
      includeFunnel
    )
      .then((response) => {
        if (cancelled) return
        setActiveColumnResults(response?.next || [])
        if (includeFunnel) {
          setFunnel(response?.funnel || [])
          setProvisionalFunnelEntries({})
        }
      })
      .catch(() => {
        if (cancelled) return
        setActiveColumnResults([])
        if (includeFunnel) setFunnel([])
      })
      .finally(() => {
        if (!cancelled) setActiveColumnLoading(false)
      })

    return () => {
      cancelled = true
    }
  }, [site, dashboardState, steps, direction, activeColumnFilter])

  const numColumns = Math.max(steps.length + 1, 3)
  const activeColumnIndex = steps.length
  const scrollRef = useRef(null)

  const lastFunnelStep = funnel.length >= 2 ? funnel[funnel.length - 1] : null
  const overallConversionRate = lastFunnelStep?.conversion_rate ?? null
  const overallConversionVisitors = lastFunnelStep?.visitors ?? null
  const totalVisitors = funnel[0]?.visitors ?? null
  const dropoffVisitors =
    totalVisitors != null && overallConversionVisitors != null
      ? totalVisitors - overallConversionVisitors
      : null
  const dropoffRate =
    overallConversionRate != null
      ? parseFloat((100 - parseFloat(overallConversionRate)).toFixed(1))
      : null

  useEffect(() => {
    const el = scrollRef.current
    if (!el) return
    el.scrollTo({ left: el.scrollWidth, behavior: 'smooth' })
  }, [steps.length])

  return (
    <div className="flex flex-col gap-4 pt-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-col">
          <h4 className="text-base font-semibold dark:text-gray-100">
            {funnel.length >= 2
              ? `${funnel.length}-step user journey`
              : 'Explore user journeys'}
          </h4>
        </div>
        <div className="flex items-center gap-3">
          {overallConversionRate != null && (
            <>
              <div className="flex items-center gap-2 text-xs text-gray-500 dark:text-gray-400">
                <span>
                  <span className="font-semibold text-gray-700 dark:text-gray-200">
                    Conversion: {parseFloat(overallConversionRate).toFixed(1)}%{' '}
                  </span>
                  <span className="text-gray-400 dark:text-gray-500">
                    ({numberShortFormatter(overallConversionVisitors)})
                  </span>
                </span>
                <span className="text-gray-300 dark:text-gray-700 select-none">
                  |
                </span>
                <span>
                  <span className="font-semibold text-gray-700 dark:text-gray-200">
                    Dropoff: {dropoffRate}%{' '}
                  </span>
                  <span className="text-gray-400 dark:text-gray-500">
                    ({numberShortFormatter(dropoffVisitors)})
                  </span>
                </span>
                <span className="text-gray-300 dark:text-gray-700 select-none">
                  |
                </span>
              </div>
            </>
          )}
          <Tooltip info="Reset">
            <button
              onClick={handleReset}
              className={`${popover.toggleButton.classNames.rounded} ${popover.toggleButton.classNames.outline} justify-center !h-7 px-1.5`}
            >
              <RefreshIcon className="size-3.5" />
            </button>
          </Tooltip>
        </div>
      </div>

      <div
        ref={scrollRef}
        className="relative flex gap-6 overflow-x-auto -mx-5 px-5 -mb-3 pb-3"
      >
        {Array.from({ length: numColumns }, (_, i) => {
          const isActive = i === activeColumnIndex
          const isReachable = steps.length >= i

          return (
            <ExplorationColumn
              key={i}
              colIndex={i}
              header={columnHeader(i, direction)}
              active={isReachable}
              // Active column gets live results; previously-active (now
              // selected) columns get the candidate list that was visible at
              // the moment of selection so the user can switch options
              // without losing context. Pre-selected columns (e.g. populated
              // by interesting-funnel preload) have no frozen results and
              // fall back to a single-item display sourced from funnel data.
              results={
                isActive ? activeColumnResults : frozenColumnResults[i] || []
              }
              loading={isActive ? activeColumnLoading : false}
              selected={steps[i] || null}
              selectedVisitors={
                funnel[i]?.visitors ??
                provisionalFunnelEntries[i]?.visitors ??
                null
              }
              selectedConversionRate={
                funnel[i]?.conversion_rate ??
                provisionalFunnelEntries[i]?.conversion_rate ??
                null
              }
              maxVisitors={funnel[0]?.visitors ?? null}
              onSelect={(selected) => handleSelect(i, selected)}
              onFilterChange={isActive ? setActiveColumnFilter : () => {}}
              filter={isActive ? activeColumnFilter : ''}
              direction={direction}
              onDirectionChange={i === 0 ? handleDirectionSelect : undefined}
              headerConversionRate={
                funnel[i]?.conversion_rate != null
                  ? i === 0
                    ? '100%'
                    : `${parseFloat(funnel[i].conversion_rate).toFixed(1)}%`
                  : null
              }
            />
          )
        })}
        <PathConnectors scrollRef={scrollRef} steps={steps} />
      </div>
    </div>
  )
}

export default FunnelExploration
