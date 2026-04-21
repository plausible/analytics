import React, { useState, useEffect, useRef } from 'react'
import * as api from '../api'
import * as url from '../util/url'
import { useDebounce } from '../custom-hooks'
import { useSiteContext } from '../site-context'
import { useDashboardStateContext } from '../dashboard-state-context'
import { numberShortFormatter } from '../util/number-formatter'

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
  return steps.map((s) => ({ name: s.name, pathname: s.pathname }))
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

function fetchSuggestedJourney(site, dashboardState) {
  return api.post(
    url.apiPath(site, '/exploration/interesting-funnel'),
    dashboardState,
    {}
  )
}

function isSameStep(step, otherStep) {
  return step.name === otherStep.name && step.pathname === otherStep.pathname
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
  filter
}) {
  const debouncedOnFilterChange = useDebounce((event) =>
    onFilterChange(event.target.value)
  )

  const stepMaxVisitors = maxVisitors || results[0]?.visitors

  // When a step is selected we show only that one item.
  // If the full results list has loaded and contains a matching entry we use it
  // so the bar widths are still relative to the column's data; otherwise we
  // fall back to a synthetic item built from the funnel data
  const selectedResult =
    selected && results.find(({ step }) => isSameStep(step, selected))

  const listItems = selected
    ? [
        selectedResult || {
          step: selected,
          visitors: selectedVisitors ?? 0
        }
      ]
    : results.slice(0, 10)

  return (
    <div className="min-w-80 flex-1 border border-gray-200 dark:border-gray-750 rounded-lg overflow-hidden">
      <div className="h-12 pl-4 pr-1.5 flex items-center justify-between">
        <span className="shrink-0 text-xs font-medium text-gray-500 dark:text-gray-400">
          {header}
        </span>
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
        {selected && (
          <button
            onClick={() => onSelect(null)}
            className="pr-2.5 text-xs text-indigo-500 font-medium hover:text-indigo-700 dark:text-indigo-400 dark:hover:text-indigo-200"
          >
            Clear
          </button>
        )}
      </div>

      {loading ? (
        <div className="h-112 flex items-center justify-center">
          <div className="mx-auto loading pt-4">
            <div></div>
          </div>
        </div>
      ) : results.length === 0 && !selected ? (
        <div className="h-108 flex items-center justify-center text-sm text-gray-400 dark:text-gray-500">
          {!active ? 'Select an event to continue' : 'No data'}
        </div>
      ) : (
        <ul className="flex flex-col gap-y-0.5 px-1.5 pb-1.5 h-108 overflow-y-auto">
          {listItems.map(({ step, visitors }) => {
            const isSelected = !!selected && isSameStep(step, selected)
            const visitorsToShow =
              isSelected && selectedVisitors !== null
                ? selectedVisitors
                : visitors
            const barWidth =
              isSelected && selectedConversionRate !== null
                ? selectedConversionRate
                : Math.round((visitors / stepMaxVisitors) * 100)

            return (
              <li key={step.label}>
                <button
                  className={`group w-full border text-left px-2.5 pt-2 pb-2.5 text-sm rounded-md focus:outline-none ${
                    isSelected
                      ? 'bg-indigo-50/80 dark:bg-gray-750 border-indigo-50 dark:border-transparent'
                      : 'hover:bg-gray-100 dark:hover:bg-gray-800 border-transparent'
                  }`}
                  onClick={() => onSelect(isSelected ? null : step)}
                >
                  <div className="flex items-center justify-between gap-2 mb-1">
                    <span
                      className="truncate font-medium text-gray-800 dark:text-gray-200"
                      title={step.label}
                    >
                      {step.label}
                    </span>
                    <span className="shrink-0 text-gray-800 dark:text-gray-200 tabular-nums">
                      {numberShortFormatter(visitorsToShow)}
                    </span>
                  </div>
                  <div
                    className={`h-1 rounded-full overflow-hidden 
                    ${isSelected ? 'bg-indigo-100 dark:bg-gray-700' : 'bg-indigo-100/70 dark:bg-gray-700 group-hover:bg-indigo-100 dark:group-hover:bg-gray-600'}`}
                  >
                    <div
                      className={`h-full rounded-full transition-[width] ease-in-out ${
                        isSelected
                          ? 'bg-indigo-500 dark:bg-white'
                          : 'bg-indigo-300 dark:bg-gray-300 group-hover:bg-indigo-400 dark:group-hover:bg-white'
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
  // Initial visitor/bar data for a newly selected step, held until
  // real funnel response arrives. Prevents from flashing "0 visitors"
  // during the loading window.
  const [provisionalFunnelEntries, setProvisionalFunnelEntries] = useState({})
  // track in flight "Suggest a journey" request
  const [isSuggestingJourney, setIsSuggestingJourney] = useState(false)
  // counter to detect and discard stale suggestion responses
  const suggestionRequestIdRef = useRef(0)
  // Tracks the steps/direction/dashboardState values from the previous effect
  // run so we can tell whether the journey changed (needs funnel) or only the
  // search filter changed (next steps only, no funnel).
  const prevStepsRef = useRef(steps)
  const prevDirectionRef = useRef(direction)
  const prevDashboardStateRef = useRef(dashboardState)

  function cancelPendingSuggestion() {
    suggestionRequestIdRef.current += 1
    setIsSuggestingJourney(false)
  }

  function handleSuggestJourney() {
    if (isSuggestingJourney) {
      return
    }

    const requestId = ++suggestionRequestIdRef.current
    setIsSuggestingJourney(true)

    fetchSuggestedJourney(site, dashboardState)
      .then((response) => {
        // newer request (or an explicit cancel)
        if (suggestionRequestIdRef.current !== requestId) {
          return
        }

        if (response && response.length > 0) {
          setSteps(response.map(({ step }) => step))
          setFunnel(response)
        }
      })
      .catch(() => {})
      .finally(() => {
        if (suggestionRequestIdRef.current === requestId) {
          setIsSuggestingJourney(false)
        }
      })
  }

  function handleSelect(columnIndex, selected) {
    if (isSuggestingJourney) {
      cancelPendingSuggestion()
    }

    // Reset the active-column filter whenever the journey changes
    setActiveColumnFilter('')

    if (selected === null) {
      setProvisionalFunnelEntries({})
      setActiveColumnResults([])
      setActiveColumnLoading(true)
      setSteps(steps.slice(0, columnIndex))
    } else {
      // Snapshot the clicked step's visitor count from the current results so
      // the column can display a sensible value immediately, before the funnel
      // API response arrives. The bar width is computed relative to the first
      // step's visitor count (same baseline the real funnel uses).
      const match = activeColumnResults.find(({ step }) =>
        isSameStep(step, selected)
      )
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
      setActiveColumnResults([])
      setActiveColumnLoading(true)
      setSteps([...steps.slice(0, columnIndex), selected])
    }
  }

  function handleDirectionSelect(nextDirection) {
    if (nextDirection === direction) return

    if (isSuggestingJourney) {
      cancelPendingSuggestion()
    }

    setDirection(nextDirection)
    setSteps(steps.toReversed())
    setFunnel([])
    setActiveColumnResults([])
    setActiveColumnFilter('')
    setProvisionalFunnelEntries({})
  }

  // Fetch next step suggestions (and funnel, if the journey changed) whenever
  // the journey, direction, dashboard filters, or search term change.
  // Funnel is only re-fetched when steps or direction/dashboardState change,
  // search doesn't affect it.
  useEffect(() => {
    setActiveColumnLoading(true)
    setActiveColumnResults([])

    const journeyChanged =
      prevStepsRef.current !== steps ||
      prevDirectionRef.current !== direction ||
      prevDashboardStateRef.current !== dashboardState

    prevStepsRef.current = steps
    prevDirectionRef.current = direction
    prevDashboardStateRef.current = dashboardState

    const includeFunnel = journeyChanged && steps.length > 0

    if (journeyChanged && steps.length === 0) {
      setFunnel([])
    }

    let cancelled = false

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

  useEffect(() => {
    const el = scrollRef.current
    if (!el) return
    el.scrollTo({ left: el.scrollWidth, behavior: 'smooth' })
  }, [steps.length])

  return (
    <div className="flex flex-col gap-4 pt-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-col">
          <h4 className="text-base font-semibold dark:text-gray-100">
            Explore
          </h4>
        </div>
        <div className="flex shrink-0 items-center gap-3">
          {steps.length === 0 &&
            direction === EXPLORATION_DIRECTIONS.FORWARD && (
              <button
                onClick={handleSuggestJourney}
                disabled={isSuggestingJourney}
                className="text-xs font-medium text-indigo-500 hover:text-indigo-700 dark:text-indigo-400 dark:hover:text-indigo-200 disabled:opacity-50"
              >
                {isSuggestingJourney ? 'Suggesting...' : 'Suggest a journey'}
              </button>
            )}
          <div className="flex gap-1 overflow-hidden">
            <button
              onClick={() =>
                handleDirectionSelect(EXPLORATION_DIRECTIONS.FORWARD)
              }
              className={`px-2 py-1.5 text-xs font-medium rounded-md ${
                direction === EXPLORATION_DIRECTIONS.FORWARD
                  ? 'bg-gray-150 text-gray-900 dark:bg-gray-750 dark:text-gray-100'
                  : 'text-gray-500 dark:text-gray-400'
              }`}
            >
              Starting point
            </button>
            <button
              onClick={() =>
                handleDirectionSelect(EXPLORATION_DIRECTIONS.BACKWARD)
              }
              className={`px-2 py-1.5 text-xs font-medium rounded-md ${
                direction === EXPLORATION_DIRECTIONS.BACKWARD
                  ? 'bg-gray-150 text-gray-900 dark:bg-gray-750 dark:text-gray-100'
                  : 'text-gray-500 dark:text-gray-400'
              }`}
            >
              End point
            </button>
          </div>
        </div>
      </div>

      <div
        ref={scrollRef}
        className="flex gap-4 overflow-x-auto -mx-5 px-5 -mb-3 pb-3"
      >
        {Array.from({ length: numColumns }, (_, i) => {
          const isActive = i === activeColumnIndex
          const isReachable = steps.length >= i

          return (
            <ExplorationColumn
              key={i}
              header={columnHeader(i, direction)}
              active={isReachable}
              // Active column gets live results; selected columns show a single
              // item sourced from funnel data (passed as selectedVisitors /
              // selectedConversionRate) so they need no results of their own.
              results={isActive ? activeColumnResults : []}
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
            />
          )
        })}
      </div>
    </div>
  )
}

export default FunnelExploration
