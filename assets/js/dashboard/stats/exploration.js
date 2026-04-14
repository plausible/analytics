import React, { useState, useEffect } from 'react'
import * as api from '../api'
import * as url from '../util/url'
import { useDebounce } from '../custom-hooks'
import { useSiteContext } from '../site-context'
import { useDashboardStateContext } from '../dashboard-state-context'
import { numberShortFormatter } from '../util/number-formatter'

const PAGE_FILTER_KEYS = ['page', 'entry_page', 'exit_page']

function fetchColumnData(site, dashboardState, steps, filter) {
  // Page filters only apply to the first step — strip them for subsequent columns
  const stateToUse =
    steps.length > 0
      ? {
          ...dashboardState,
          filters: dashboardState.filters.filter(
            ([_op, key]) => !PAGE_FILTER_KEYS.includes(key)
          )
        }
      : dashboardState

  const journey = []
  if (steps.length > 0) {
    for (const s of steps) {
      journey.push({ name: s.name, pathname: s.pathname })
    }
  }

  return api.get(url.apiPath(site, '/exploration/next'), stateToUse, {
    journey: JSON.stringify(journey),
    search_term: filter
  })
}

function ExplorationColumn({
  header,
  steps,
  selected,
  onSelect,
  dashboardState
}) {
  const site = useSiteContext()
  const [loading, setLoading] = useState(steps !== null)
  const [results, setResults] = useState([])
  const [filter, setFilter] = useState('')

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

    fetchColumnData(site, dashboardState, steps, filter)
      .then((response) => {
        setResults(response || [])
      })
      .catch(() => {
        setResults([])
      })
      .finally(() => {
        setLoading(false)
      })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dashboardState, steps, filter])

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
            const pct = Math.round((visitors / maxVisitors) * 100)
            const isSelected =
              !!selected &&
              step.name === selected.name &&
              step.pathname === selected.pathname

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
                      {numberShortFormatter(visitors)}
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

function columnHeader(index) {
  if (index === 0) return 'Start'
  return `${index} step${index === 1 ? '' : 's'} after`
}

export function FunnelExploration() {
  const { dashboardState } = useDashboardStateContext()
  const [steps, setSteps] = useState([])

  function handleSelect(columnIndex, selected) {
    if (selected === null) {
      setSteps(steps.slice(0, columnIndex))
    } else {
      setSteps([...steps.slice(0, columnIndex), selected])
    }
  }

  const numColumns = Math.max(steps.length + 1, 3)

  return (
    <div className="p-4">
      <h4 className="mt-2 mb-4 text-base font-semibold dark:text-gray-100">
        Explore user journeys
      </h4>
      <div className="flex gap-3">
        {Array.from({ length: numColumns }, (_, i) => (
          <ExplorationColumn
            key={i}
            header={columnHeader(i)}
            steps={steps.length >= i ? steps.slice(0, i) : null}
            selected={steps[i] || null}
            onSelect={(selected) => handleSelect(i, selected)}
            dashboardState={dashboardState}
          />
        ))}
      </div>
    </div>
  )
}

export default FunnelExploration
