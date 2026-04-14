import React, { useState, useEffect } from 'react'
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

  return api.get(url.apiPath(site, '/exploration/next'), stateToUse, {
    journey: JSON.stringify(journey),
    search_term: filter,
    direction
  })
}

function fetchFunnelData(site, dashboardState, steps, direction) {
  const stateToUse = stateWithApplicableFilters(dashboardState, steps)
  const journey = toJourney(steps)

  return api.get(url.apiPath(site, '/exploration/funnel'), stateToUse, {
    journey: JSON.stringify(journey),
    direction
  })
}

function ExplorationColumn({
  header,
  steps,
  selected,
  selectedVisitors,
  onSelect,
  dashboardState,
  direction
}) {
  const site = useSiteContext()
  const [loading, setLoading] = useState(steps !== null)
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
    if (selected) {
      return
    }

    if (steps === null) {
      setFilter('')
      setResults([])
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

  const maxVisitors = results.length > 0 ? results[0].visitors : 1

  return (
    <div className="flex-1 min-w-0 border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden">
      <div className="px-4 py-3 bg-gray-50 dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
        <span className="text-xs font-bold tracking-wide text-gray-500 dark:text-gray-400 uppercase">
          {header}
        </span>
        {!selected && steps !== null && (
          <input
            data-testid="search-input"
            type="text"
            defaultValue={filter}
            placeholder="Search"
            onChange={debouncedOnSearchInputChange}
            className="peer w-32 text-sm dark:text-gray-100 block border-gray-300 dark:border-gray-750 rounded-md dark:bg-gray-750 dark:placeholder:text-gray-400 focus:outline-none focus:ring-3 focus:ring-indigo-500/20 dark:focus:ring-indigo-500/25 focus:border-indigo-500"
          />
        )}
        {selected && (
          <button
            onClick={() => onSelect(null)}
            className="text-xs text-indigo-500 hover:text-indigo-700 dark:text-indigo-400 dark:hover:text-indigo-200"
          >
            Clear
          </button>
        )}
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-48">
          <div className="mx-auto loading pt-4">
            <div></div>
          </div>
        </div>
      ) : results.length === 0 ? (
        <div className="flex items-center justify-center h-48 text-sm text-gray-400 dark:text-gray-500">
          {steps === null ? 'Select an event to continue' : 'No data'}
        </div>
      ) : (
        <ul className="divide-y divide-gray-100 dark:divide-gray-700">
          {(selected
            ? results.filter(
                ({ step }) =>
                  step.name === selected.name &&
                  step.pathname === selected.pathname
              )
            : results.slice(0, 10)
          ).map(({ step, visitors }) => {
            const label = `${step.name} ${step.pathname}`
            const isSelected =
              !!selected &&
              step.name === selected.name &&
              step.pathname === selected.pathname
            const visitorsToShow =
              isSelected && selectedVisitors !== null
                ? selectedVisitors
                : visitors
            const pct = Math.round((visitorsToShow / maxVisitors) * 100)

            return (
              <li key={label}>
                <button
                  className={`w-full text-left px-4 py-2 text-sm transition-colors focus:outline-none ${
                    isSelected
                      ? 'bg-indigo-50 dark:bg-indigo-900/30'
                      : 'hover:bg-gray-50 dark:hover:bg-gray-800'
                  }`}
                  onClick={() => onSelect(isSelected ? null : step)}
                >
                  <div className="flex items-center justify-between mb-1">
                    <span
                      className={`truncate font-medium ${
                        isSelected
                          ? 'text-indigo-700 dark:text-indigo-300'
                          : 'text-gray-800 dark:text-gray-200'
                      }`}
                      title={label}
                    >
                      {label}
                    </span>
                    <span className="ml-2 shrink-0 text-gray-500 dark:text-gray-400 tabular-nums">
                      {numberShortFormatter(visitorsToShow)}
                    </span>
                  </div>
                  <div className="h-1 rounded-full bg-gray-100 dark:bg-gray-700 overflow-hidden">
                    <div
                      className={`h-full rounded-full ${
                        isSelected
                          ? 'bg-indigo-500'
                          : 'bg-indigo-300 dark:bg-indigo-600'
                      }`}
                      style={{ width: `${pct}%` }}
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
    return direction === EXPLORATION_DIRECTIONS.BACKWARD ? 'End' : 'Start'
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

  function handleSelect(columnIndex, selected) {
    if (selected === null) {
      setSteps(steps.slice(0, columnIndex))
    } else {
      setSteps([...steps.slice(0, columnIndex), selected])
    }
  }

  function handleDirectionSelect(nextDirection) {
    if (nextDirection === direction) return
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

  return (
    <div className="p-4">
      <div className="mt-2 mb-4 flex flex-wrap items-center justify-between gap-3">
        <h4 className="text-base font-semibold dark:text-gray-100">
          Explore user journeys
        </h4>
        <div className="flex shrink-0 rounded-md border border-gray-200 dark:border-gray-700 overflow-hidden">
          <button
            onClick={() =>
              handleDirectionSelect(EXPLORATION_DIRECTIONS.FORWARD)
            }
            className={`px-3 py-1 text-xs font-semibold transition-colors ${
              direction === EXPLORATION_DIRECTIONS.FORWARD
                ? 'bg-indigo-500 text-white'
                : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300'
            }`}
          >
            Forward
          </button>
          <button
            onClick={() =>
              handleDirectionSelect(EXPLORATION_DIRECTIONS.BACKWARD)
            }
            className={`px-3 py-1 text-xs font-semibold transition-colors border-l border-gray-200 dark:border-gray-700 ${
              direction === EXPLORATION_DIRECTIONS.BACKWARD
                ? 'bg-indigo-500 text-white'
                : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300'
            }`}
          >
            Backward
          </button>
        </div>
      </div>
      <div
        className={`flex gap-3 ${direction === 'backward' ? 'flex-row-reverse' : ''}`}
      >
        {Array.from({ length: numColumns }, (_, i) => (
          <ExplorationColumn
            key={i}
            header={columnHeader(i, direction)}
            steps={steps.length >= i ? steps.slice(0, i) : null}
            selected={steps[i] || null}
            selectedVisitors={funnel[i]?.visitors ?? null}
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
