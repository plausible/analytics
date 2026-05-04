import React, {
  useState,
  useEffect,
  useLayoutEffect,
  useRef,
  useCallback
} from 'react'
import LazyLoader from '../components/lazy-loader'
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
import { RefreshIcon, CursorIcon } from '../components/icons'
import { ChevronUpDownIcon, ChevronRightIcon } from '@heroicons/react/20/solid'
import { FlagIcon, MagnifyingGlassIcon } from '@heroicons/react/24/outline'
import { popover } from '../components/popover'

const PAGE_FILTER_KEYS = ['page', 'entry_page', 'exit_page']
const EXPLORATION_DIRECTIONS = {
  FORWARD: 'forward',
  BACKWARD: 'backward'
}

function randomKey() {
  return Math.random().toString()
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
    <div ref={ref} className="relative shrink-0">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex items-center gap-0.5 text-xs font-semibold text-gray-900 dark:text-gray-100 hover:text-gray-700 dark:hover:text-gray-200"
      >
        {label}
        <ChevronUpDownIcon className="size-3.5 shrink-0" />
      </button>
      {open && (
        <div
          className={`absolute -left-1 top-full mt-1 z-10 min-w-40 dark:!bg-gray-900 ${popover.panel.classNames.roundedSheet}`}
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
              className={`w-full text-left text-sm rounded-md dark:hover:!bg-gray-750 data-[selected=true]:dark:!bg-gray-750 ${popover.items.classNames.navigationLink} ${popover.items.classNames.hoverLink} ${
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

// Returns the x coordinate of a column's right or left edge,
// adjusted for the container's scroll position so it is stable
// in SVG/document space even when the user scrolls horizontally.
function columnEdgeX(colEl, side, containerRect, scrollLeft) {
  const rect = colEl.getBoundingClientRect()
  const edgeX = side === 'right' ? rect.right : rect.left
  return edgeX - containerRect.left + scrollLeft
}

// Returns the vertical midpoint of a step row element relative to
// the top of the scroll container (not the viewport).
function stepRowMidY(stepRowEl, containerRect) {
  const rect = stepRowEl.getBoundingClientRect()
  return (rect.top + rect.bottom) / 2 - containerRect.top
}

// Builds an SVG path string for a stepped connector with rounded
// corners between two points. The path goes: horizontal → rounded
// corner → vertical → rounded corner → horizontal.
function steppedPath(x1, y1, x2, y2) {
  const mx = (x1 + x2) / 2
  const dy = y2 - y1

  if (Math.abs(dy) < 1) {
    // Points are on the same horizontal line — plain horizontal segment.
    return `M ${x1} ${y1} H ${x2}`
  }

  const r = Math.min(10, Math.abs(dy) / 2)

  if (dy > 0) {
    // Target is below: corners curve downward then outward.
    return `M ${x1} ${y1} H ${mx - r} A ${r} ${r} 0 0 1 ${mx} ${y1 + r} V ${y2 - r} A ${r} ${r} 0 0 0 ${mx + r} ${y2} H ${x2}`
  } else {
    // Target is above: corners curve upward then outward.
    return `M ${x1} ${y1} H ${mx - r} A ${r} ${r} 0 0 0 ${mx} ${y1 - r} V ${y2 + r} A ${r} ${r} 0 0 1 ${mx + r} ${y2} H ${x2}`
  }
}

// Computes the clip rect that confines connectors to the list area,
// so they don't bleed into column headers.
function listClipRect(container, containerRect) {
  const firstList = container.querySelector('[data-exploration-list]')
  const listRect = firstList ? firstList.getBoundingClientRect() : null
  return {
    y: listRect ? listRect.top - containerRect.top : 0,
    height: listRect ? listRect.height : container.clientHeight
  }
}

function emptyConnectorSvgData() {
  return {
    paths: [],
    width: 0,
    height: 0,
    clipY: 0,
    clipHeight: 0
  }
}

function calculateConnectors(container, steps) {
  const containerRect = container.getBoundingClientRect()
  const newPaths = []

  const columns = container.querySelectorAll(`[data-exploration-column]`)
  const stepRows = container.querySelectorAll(`[data-exploration-step]`)

  for (let i = 0; i < steps.length - 1; i++) {
    const colA = columns[i]
    const colB = columns[i + 1]

    const stepRowA = stepRows[i]
    const stepRowB = stepRows[i + 1]

    if (colA && stepRowA && colB && stepRowB) {
      const x1 = columnEdgeX(colA, 'right', containerRect, container.scrollLeft)
      const x2 = columnEdgeX(colB, 'left', containerRect, container.scrollLeft)
      const y1 = stepRowMidY(stepRowA, containerRect)
      const y2 = stepRowMidY(stepRowB, containerRect)

      newPaths.push(steppedPath(x1, y1, x2, y2))
    }
  }

  const clip = listClipRect(container, containerRect)

  return {
    paths: newPaths,
    width: container.scrollWidth,
    height: container.clientHeight,
    clipY: clip.y,
    clipHeight: clip.height
  }
}

function PathConnectors({ steps, containerRef }) {
  const [svgData, setSvgData] = useState(emptyConnectorSvgData)

  const calculateCallback = useCallback(() => {
    const container = containerRef.current

    if (container) {
      setSvgData(calculateConnectors(container, steps))
    }
  }, [steps, containerRef])

  useLayoutEffect(() => {
    const container = containerRef.current

    if (!container || steps.length < 2) {
      setSvgData(emptyConnectorSvgData)
      return
    } else {
      setSvgData(calculateConnectors(container, steps))

      const observer = new ResizeObserver(calculateCallback)
      observer.observe(container)
      window.addEventListener('resize', calculateCallback)

      const lists = Array.from(
        container.querySelectorAll('[data-exploration-list]')
      )

      lists.forEach((list) =>
        list.addEventListener('scroll', calculateCallback)
      )

      return () => {
        observer.disconnect()
        window.removeEventListener('resize', calculateCallback)
        lists.forEach((list) =>
          list.removeEventListener('scroll', calculateCallback)
        )
      }
    }
  }, [steps, containerRef, calculateCallback])

  if (svgData.paths.length === 0) return null

  return (
    <svg
      className="absolute inset-0 pointer-events-none overflow-visible"
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
          className="stroke-indigo-500 dark:stroke-indigo-400"
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
  colIndex,
  className
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
      className={`bg-gray-50 dark:bg-gray-850 rounded-lg overflow-hidden ${className || ''}`}
    >
      <div className="h-[42px] py-2 pl-4 pr-1.5 flex items-center justify-between gap-x-2">
        {onDirectionChange ? (
          <DirectionDropdown
            direction={direction}
            onDirectionChange={onDirectionChange}
          />
        ) : (
          <span className="shrink-0 text-xs font-semibold text-gray-900 dark:text-gray-100">
            {header}
          </span>
        )}
        {!selected && active && (results.length > 0 || filter) && (
          <input
            data-testid="search-input"
            type="text"
            defaultValue={filter}
            placeholder="Search"
            onChange={debouncedOnFilterChange}
            className="peer max-w-48 w-full text-xs dark:text-gray-100 block border-gray-300 dark:border-gray-700 rounded-md dark:bg-gray-700 dark:placeholder:text-gray-400 focus:outline-none focus:ring-3 focus:ring-indigo-500/20 dark:focus:ring-indigo-500/25 focus:border-indigo-500"
          />
        )}
        {headerConversionRate && (
          <span className="shrink-0 text-xs font-semibold text-gray-900 dark:text-gray-100">
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
        <div className="h-110 flex items-center justify-center max-w-2/3 mx-auto text-center text-sm text-pretty text-gray-400 dark:text-gray-500">
          {!active ? (
            <span className="flex flex-col items-center gap-2">
              <CursorIcon className="size-5" />
              {colIndex === 1
                ? direction === EXPLORATION_DIRECTIONS.BACKWARD
                  ? 'Select an end point to continue'
                  : 'Select a starting point to continue'
                : 'Select an event to continue'}
            </span>
          ) : filter ? (
            <span className="flex flex-col items-center gap-2">
              <MagnifyingGlassIcon className="size-4.5" />
              {'No events found'}
            </span>
          ) : (
            <span className="flex flex-col items-center gap-2">
              <FlagIcon className="size-4.5" />
              {direction === EXPLORATION_DIRECTIONS.BACKWARD
                ? "You've reached the beginning of this journey"
                : "You've reached the end of this journey"}
            </span>
          )}
        </div>
      ) : (
        <ul
          data-exploration-list
          className="flex flex-col gap-y-2 px-2 pb-2 h-110 overflow-y-auto [scrollbar-width:thin] [scrollbar-color:theme(colors.gray.300)_transparent] dark:[scrollbar-color:theme(colors.gray.600)_transparent]"
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
            const label = step.label

            return (
              <li key={label}>
                <button
                  data-exploration-step={isSelected ? colIndex : undefined}
                  className={`group w-full border text-left px-4 py-3 text-sm rounded-md focus:outline-none ${
                    isSelected
                      ? 'bg-indigo-50 dark:bg-gray-600/70 border-indigo-100 dark:border-transparent'
                      : 'bg-white dark:bg-gray-750 border-gray-150 dark:border-gray-750'
                  }`}
                  onClick={() => onSelect(isSelected ? null : step)}
                >
                  <div className="flex items-center justify-between gap-2 mb-1">
                    <span
                      className={`flex items-center gap-1.5 min-w-0 ${
                        isDimmed
                          ? 'text-gray-400 dark:text-gray-500'
                          : 'text-gray-900 dark:text-gray-100'
                      }`}
                      title={
                        step.includes_subpaths
                          ? `${label} > all (${step.subpaths_count})`
                          : label
                      }
                    >
                      {isCustomEvent && (
                        <CursorIcon
                          title="Custom event"
                          className={`size-4 shrink-0 ${isDimmed ? 'text-gray-300 dark:text-gray-600' : 'text-gray-900 dark:text-gray-100'}`}
                        />
                      )}
                      <span className="truncate">{label}</span>
                      {step.includes_subpaths && (
                        <>
                          <ChevronRightIcon
                            className={`mt-0.5 size-3 shrink-0 ${isDimmed ? 'text-gray-400 dark:text-gray-500' : 'text-gray-500 dark:text-gray-400'}`}
                          />
                          <span
                            className={`shrink-0 ${isDimmed ? 'text-gray-400 dark:text-gray-500' : 'text-gray-500 dark:text-gray-400'}`}
                          >
                            all{' '}
                            <span className="text-[0.85rem]">
                              ({numberShortFormatter(step.subpaths_count)})
                            </span>
                          </span>
                        </>
                      )}
                    </span>
                    <span
                      className={`shrink-0 font-medium ${
                        isDimmed
                          ? 'text-gray-400 dark:text-gray-500'
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
                        ? 'bg-indigo-200/70 dark:bg-gray-500/60'
                        : isDimmed
                          ? 'bg-gray-150 dark:bg-gray-700'
                          : 'bg-gray-150 dark:bg-gray-600'
                    }`}
                  >
                    <div
                      className={`h-full rounded-full transition-[width] ease-in-out ${
                        isSelected
                          ? 'bg-indigo-500 dark:bg-indigo-400'
                          : isDimmed
                            ? 'bg-indigo-200 dark:bg-indigo-400/30'
                            : 'bg-indigo-300 dark:bg-indigo-400/75 group-hover:bg-indigo-400 dark:group-hover:bg-indigo-400'
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
  const [inViewport, setInViewport] = useState(false)

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
  // Workaround for force refreshing connectors between steps
  // when dashboardState changes. Currently the connectors
  // logic extracts part of the state from DOM, which shouldn't be the
  // case. It will eventually be properlu rewritten and the workaround
  // will no longer be needed.
  const [connectorsKey, setConnectorsKey] = useState(randomKey)
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
    if (!inViewport) return

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
          if (response && response.funnel && response.funnel.length > 0) {
            funnelFromPreloadRef.current = true
            const preloadedSteps = response.funnel.map(({ step }) => step)
            setSteps(preloadedSteps)
            setFunnel(response.funnel)
            setFrozenColumnResults(response.candidates)
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

    setConnectorsKey(randomKey)

    return () => {
      cancelled = true
    }
  }, [site, dashboardState, steps, direction, activeColumnFilter, inViewport])

  const initialLoading =
    !inViewport || (steps.length === 0 && activeColumnLoading)
  const journeyEnded =
    !activeColumnLoading &&
    activeColumnResults.length === 0 &&
    steps.length >= 1
  const numColumns = initialLoading
    ? 1
    : journeyEnded || (activeColumnLoading && steps.length === 1)
      ? steps.length + 1
      : Math.max(steps.length + 1, 3)
  const gridColumns = Math.max(numColumns, 3)
  const activeColumnIndex = steps.length
  const containerRef = useRef(null)

  const lastFunnelStep = funnel.length >= 2 ? funnel[funnel.length - 1] : null
  const overallConversionRate = lastFunnelStep?.conversion_rate ?? null
  const overallConversionVisitors = lastFunnelStep?.visitors ?? null

  const prevStepsLengthRef = useRef(0)
  useEffect(() => {
    const el = containerRef.current
    if (!el) return
    if (steps.length !== prevStepsLengthRef.current) {
      const activeColumn = el.querySelector(
        `[data-exploration-column="${steps.length}"]`
      )
      if (activeColumn) {
        const { left: colLeft, right: colRight } =
          activeColumn.getBoundingClientRect()
        const { left: containerLeft, right: containerRight } =
          el.getBoundingClientRect()
        if (colRight > containerRight || colLeft < containerLeft) {
          el.scrollTo({
            left: el.scrollLeft + colLeft - containerLeft,
            behavior: 'smooth'
          })
        }
      } else {
        el.scrollTo({ left: el.scrollWidth, behavior: 'smooth' })
      }
    }
    prevStepsLengthRef.current = steps.length
  }, [steps.length])

  return (
    <LazyLoader onVisible={() => setInViewport(true)}>
      <div className="flex flex-col gap-4 pt-4">
        <div className="flex flex-wrap items-center gap-x-3">
          <h4 className="flex-1 text-base font-semibold dark:text-gray-100">
            {funnel.length >= 2
              ? `${funnel.length}-step user journey`
              : 'Explore user journeys'}
          </h4>
          {overallConversionRate != null && (
            <div className="order-last sm:order-none w-full sm:w-auto flex items-center gap-2 text-xs text-gray-500 dark:text-gray-400">
              <span>
                <span className="font-medium sm:font-semibold text-gray-700 dark:text-gray-200">
                  Conversion: {parseFloat(overallConversionRate).toFixed(1)}%{' '}
                </span>
                <span className="text-gray-500 dark:text-gray-400">
                  ({numberShortFormatter(overallConversionVisitors)})
                </span>
              </span>
              <span className="hidden sm:inline text-gray-300 dark:text-gray-600 select-none">
                |
              </span>
            </div>
          )}
          <Tooltip
            info={<span className="whitespace-nowrap">Deselect all</span>}
            className={
              steps.length === 0 ? 'invisible pointer-events-none' : ''
            }
          >
            <button
              onClick={handleReset}
              className={`${popover.toggleButton.classNames.rounded} ${popover.toggleButton.classNames.outline} justify-center !h-7 px-1.5`}
            >
              <RefreshIcon className="size-3.5" />
            </button>
          </Tooltip>
        </div>

        <div
          ref={containerRef}
          className="relative grid gap-6 overflow-x-auto -mx-5 px-5 -mb-3 pb-3 [scrollbar-width:thin] [scrollbar-color:theme(colors.gray.300)_transparent] dark:[scrollbar-color:theme(colors.gray.600)_transparent]"
          style={{
            gridTemplateColumns: `repeat(${gridColumns}, minmax(20rem, 1fr))`
          }}
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
                loading={
                  isActive ? initialLoading || activeColumnLoading : false
                }
                selected={steps[i] || null}
                selectedVisitors={
                  provisionalFunnelEntries[i]?.visitors ??
                  funnel[i]?.visitors ??
                  null
                }
                selectedConversionRate={
                  provisionalFunnelEntries[i]?.conversion_rate ??
                  funnel[i]?.conversion_rate ??
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
          <PathConnectors
            key={connectorsKey}
            containerRef={containerRef}
            steps={steps}
          />
        </div>
      </div>
    </LazyLoader>
  )
}

export default FunnelExploration
