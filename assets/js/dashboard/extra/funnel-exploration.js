import React, { useState, useEffect } from 'react'
import * as api from '../api'
import { useDashboardStateContext } from '../dashboard-state-context'
import { useSiteContext } from '../site-context'
import { createStatsQuery } from '../stats-query'
import { numberShortFormatter } from '../util/number-formatter'

function fetchColumnData(site, dashboardState, steps) {
  const query = createStatsQuery(dashboardState, {
    dimensions: ['event:label'],
    metrics: ['visitors']
  })

  if (steps.length > 0) {
    const seqFilter = ['sequence', steps.map((s) => ['is', 'event:label', [s]])]
    query.filters = [...query.filters, seqFilter]
  }

  return api.stats(site, query)
}

function ExplorationColumn({ header, steps, selected, onSelect, dashboardState }) {
  const site = useSiteContext()
  const [loading, setLoading] = useState(steps !== null)
  const [results, setResults] = useState([])

  useEffect(() => {
    if (steps === null) {
      setResults([])
      setLoading(false)
      return
    }

    setLoading(true)
    setResults([])

    fetchColumnData(site, dashboardState, steps)
      .then((response) => {
        setResults(response.results || [])
      })
      .catch(() => {
        setResults([])
      })
      .finally(() => {
        setLoading(false)
      })
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dashboardState, steps === null ? null : steps.join('|||')])

  const maxVisitors = results.length > 0 ? results[0].metrics[0] : 1

  return (
    <div className="flex-1 min-w-0 border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden">
      <div className="px-4 py-3 bg-gray-50 dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
        <span className="text-xs font-bold tracking-wide text-gray-500 dark:text-gray-400 uppercase">
          {header}
        </span>
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
          {(selected ? results.filter(({ dimensions }) => dimensions[0] === selected) : results.slice(0, 10)).map(({ dimensions, metrics }) => {
            const label = dimensions[0]
            const visitors = metrics[0]
            const pct = Math.round((visitors / maxVisitors) * 100)
            const isSelected = selected === label

            return (
              <li key={label}>
                <button
                  className={`w-full text-left px-4 py-2 text-sm transition-colors focus:outline-none ${
                    isSelected
                      ? 'bg-indigo-50 dark:bg-indigo-900/30'
                      : 'hover:bg-gray-50 dark:hover:bg-gray-800'
                  }`}
                  onClick={() => onSelect(isSelected ? null : label)}
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
                        isSelected ? 'bg-indigo-500' : 'bg-indigo-300 dark:bg-indigo-600'
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

export function FunnelExploration() {
  const { dashboardState } = useDashboardStateContext()
  const [step1, setStep1] = useState(null)
  const [step2, setStep2] = useState(null)

  function handleStep1Select(label) {
    setStep1(label)
    setStep2(null)
  }

  return (
    <div className="p-4">
      <h4 className="mt-2 mb-4 text-base font-semibold dark:text-gray-100">
        Explore user journeys
      </h4>
      <div className="flex gap-3">
        <ExplorationColumn
          header="Start"
          steps={[]}
          selected={step1}
          onSelect={handleStep1Select}
          dashboardState={dashboardState}
        />
        <ExplorationColumn
          header="1 step after"
          steps={step1 !== null ? [step1] : null}
          selected={step2}
          onSelect={setStep2}
          dashboardState={dashboardState}
        />
        <ExplorationColumn
          header="2 steps after"
          steps={step2 !== null ? [step1, step2] : null}
          selected={null}
          onSelect={() => {}}
          dashboardState={dashboardState}
        />
      </div>
    </div>
  )
}

export default FunnelExploration
