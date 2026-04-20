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

function fetchColumnData(site, dashboardState, steps, filter, direction) {
  // Page filters only apply to the first step — strip them for subsequent columns
  const stateToUse = stateWithApplicableFilters(dashboardState, steps)
  const journey = toJourney(steps)

  return api.post(url.apiPath(site, '/exploration/next'), stateToUse, {
    journey: JSON.stringify(journey),
    search_term: filter,
    direction
  })
}

function fetchFunnelData(site, dashboardState, steps, direction) {
  const stateToUse = stateWithApplicableFilters(dashboardState, steps)
  const journey = toJourney(steps)

  return api.post(url.apiPath(site, '/exploration/funnel'), stateToUse, {
    journey: JSON.stringify(journey),
    direction
  })
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
  steps,
  maxVisitors,
  selected,
  selectedVisitors,
  selectedConversionRate,
  onSelect,
  dashboardState,
  direction
}) {
  const site = useSiteContext()
  const [loading, setLoading] = useState(steps !== null && !selected)
  const [results, setResults] = useState([])
  const [filter, setFilter] = useState('')
  const stepsFingerprint =
    steps === null
      ? null
      : steps.map((step) => `${step.name}:${step.pathname}`).join(';')

  const debouncedOnSearchInputChange = useDebounce((event) =>
    setFilter(event.target.value)
  )

  useEffect(() => {
    if (steps === null) {
      setFilter('')
      setResults([])
      setLoading(false)
      return
    }

    if (selected) {
      // When a step is already selected (pre-populated by "Suggest a journey"),
      // fetch is unnecessary
      setLoading(false)
      return
    }

    setLoading(true)
    setResults([])

    let cancelled = false

    fetchColumnData(site, dashboardState, steps, filter, direction)
      .then((response) => {
        if (!cancelled) {
          setResults(response || [])
        }
      })
      .catch(() => {
        if (!cancelled) {
          setResults([])
        }
      })
      .finally(() => {
        if (!cancelled) {
          setLoading(false)
        }
      })

    return () => {
      cancelled = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dashboardState, stepsFingerprint, filter, direction, site, selected])

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
        {!selected && steps !== null && (
          <input
            data-testid="search-input"
            type="text"
            defaultValue={filter}
            placeholder="Search"
            onChange={debouncedOnSearchInputChange}
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
          {steps === null ? 'Select an event to continue' : 'No data'}
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
  // track in flight "Suggest a journey" request
  const [isSuggestingJourney, setIsSuggestingJourney] = useState(false)
  // counter to detect and discard stale suggestion responses
  const suggestionRequestIdRef = useRef(0)

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

    if (selected === null) {
      setSteps(steps.slice(0, columnIndex))
    } else {
      setSteps([...steps.slice(0, columnIndex), selected])
    }
  }

  function handleDirectionSelect(nextDirection) {
    if (nextDirection === direction) return

    if (isSuggestingJourney) {
      cancelPendingSuggestion()
    }

    setDirection(nextDirection)
    setSteps([])
    setFunnel([])
  }

  useEffect(() => {
    if (steps.length === 0) {
      setFunnel([])
      return
    }

    let cancelled = false

    fetchFunnelData(site, dashboardState, steps, direction)
      .then((response) => {
        if (!cancelled) {
          setFunnel(response || [])
        }
      })
      .catch(() => {
        if (!cancelled) {
          setFunnel([])
        }
      })

    return () => {
      cancelled = true
    }
  }, [site, dashboardState, steps, direction])

  const numColumns = Math.max(steps.length + 1, 3)
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
        {Array.from({ length: numColumns }, (_, i) => (
          <ExplorationColumn
            key={i}
            header={columnHeader(i, direction)}
            steps={steps.length >= i ? steps.slice(0, i) : null}
            selected={steps[i] || null}
            selectedVisitors={funnel[i]?.visitors ?? null}
            selectedConversionRate={funnel[i]?.conversion_rate ?? null}
            maxVisitors={funnel[0]?.visitors ?? null}
            onSelect={(selected) => handleSelect(i, selected)}
            dashboardState={dashboardState}
            direction={direction}
          />
        ))}
      </div>
    </div>
  )
}

export default FunnelExploration
