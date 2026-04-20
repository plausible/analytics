import React, { useState, useEffect, useRef } from 'react'
import * as api from '../api'
import * as url from '../util/url'
import { useDebounce } from '../custom-hooks'
import { useSiteContext } from '../site-context'
import { useDashboardStateContext } from '../dashboard-state-context'
import { numberShortFormatter } from '../util/number-formatter'
import { ChevronDownIcon, XMarkIcon } from '@heroicons/react/20/solid'
import { MagnifyingGlassIcon, InformationCircleIcon } from '@heroicons/react/24/outline'

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

function ExplorationStepCombobox({
  steps,
  dashboardState,
  direction,
  onSelect,
  disabled = false,
  selectedLabel = null,
  autoOpen = false,
  skipAutoOpen = false
}) {
  const site = useSiteContext()
  const [inputValue, setInputValue] = useState(selectedLabel ?? '')
  const [filter, setFilter] = useState('')
  const [isOpen, setIsOpen] = useState(false)
  const [results, setResults] = useState([])
  const [loading, setLoading] = useState(false)
  const [highlightedIndex, setHighlightedIndex] = useState(0)

  const containerRef = useRef(null)
  const inputRef = useRef(null)

  const debouncedSetFilter = useDebounce((value) => setFilter(value))

  function openAndFocus() {
    setFilter('')
    setIsOpen(true)
    setTimeout(() => inputRef.current?.focus(), 0)
  }

  // Auto-open when this column transitions from disabled → active (columns 1–3,
  // pre-mounted as disabled and later enabled by a selection upstream).
  const prevDisabledRef = useRef(disabled)
  useEffect(() => {
    if (prevDisabledRef.current && !disabled && !skipAutoOpen) openAndFocus()
    prevDisabledRef.current = disabled
  }, [disabled]) // eslint-disable-line react-hooks/exhaustive-deps

  // Auto-open when a new column mounts already active (column 4+).
  useEffect(() => {
    if (autoOpen && !disabled && !skipAutoOpen) openAndFocus()
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (!isOpen) {
      setInputValue(selectedLabel ?? '')
    }
  }, [isOpen, selectedLabel])

  useEffect(() => {
    if (!isOpen) return

    setLoading(true)
    setResults([])
    let cancelled = false

    fetchColumnData(site, dashboardState, steps, filter, direction)
      .then((response) => {
        if (!cancelled) {
          setResults(response || [])
          setHighlightedIndex(0)
        }
      })
      .catch(() => { if (!cancelled) setResults([]) })
      .finally(() => { if (!cancelled) setLoading(false) })

    return () => { cancelled = true }
  }, [isOpen, filter, direction, site, dashboardState]) // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    function handleClickOutside(e) {
      if (!containerRef.current?.contains(e.target)) closeDropdown()
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  function openDropdown() {
    setFilter(inputValue)
    setIsOpen(true)
  }

  function closeDropdown() {
    setIsOpen(false)
    setFilter('')
    // inputValue is restored by the useEffect watching [isOpen, selectedLabel]
  }

  function handleFocus() {
    if (!isOpen) openDropdown()
  }

  function handleInputChange(e) {
    const value = e.target.value
    setInputValue(value)
    debouncedSetFilter(value)
  }

  function handleChevronClick(e) {
    e.stopPropagation()
    if (disabled) return
    if (isOpen) {
      closeDropdown()
    } else {
      inputRef.current?.focus()
    }
  }

  function highlight(index) {
    if (results.length === 0) return
    setHighlightedIndex(((index % results.length) + results.length) % results.length)
  }

  function selectItem(step) {
    onSelect(step)
    setIsOpen(false)
    setFilter('')
    // Show the label immediately; the useEffect will confirm it once selectedLabel prop updates
    setInputValue(step.label)
  }

  function handleKeyDown(e) {
    if (e.key === 'ArrowDown') {
      isOpen ? highlight(highlightedIndex + 1) : inputRef.current?.focus()
      e.preventDefault()
    } else if (e.key === 'ArrowUp') {
      if (isOpen) highlight(highlightedIndex - 1)
      e.preventDefault()
    } else if (e.key === 'Enter') {
      if (isOpen && !loading && results.length > 0) selectItem(results[highlightedIndex].step)
      e.preventDefault()
    } else if (e.key === 'Escape') {
      closeDropdown()
    }
  }

  const maxVisitors = results[0]?.visitors ?? 1

  return (
    <div
      ref={containerRef}
      onKeyDown={!disabled ? handleKeyDown : undefined}
      className={`relative ${disabled ? 'opacity-50 cursor-not-allowed' : ''}`}
    >
      <div
        className={`flex items-center gap-1.5 pl-3 pr-2 py-2 rounded-md border bg-white dark:bg-gray-750 ${
          disabled
            ? 'border-gray-300 dark:border-gray-600 pointer-events-none'
            : isOpen
              ? 'border-indigo-500 ring-3 ring-indigo-500/20 dark:ring-indigo-500/25'
              : 'border-gray-300 dark:border-gray-600'
        }`}
      >
        <MagnifyingGlassIcon className="size-4 text-gray-400 shrink-0" />
        <input
          ref={inputRef}
          data-testid="search-input"
          type="text"
          value={inputValue}
          onChange={handleInputChange}
          onFocus={handleFocus}
          placeholder="Type to search"
          className="flex-1 min-w-0 text-sm bg-transparent border-none p-0 outline-none focus:ring-0 text-gray-800 dark:text-gray-200 placeholder:text-gray-500 dark:placeholder:text-gray-400"
        />
        {selectedLabel && (
          <button
            tabIndex={-1}
            onMouseDown={(e) => {
              e.preventDefault()
              onSelect(null)
              setInputValue('')
              setFilter('')
              setIsOpen(true)
              setTimeout(() => inputRef.current?.focus(), 0)
            }}
            className="shrink-0 cursor-pointer text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
          >
            <XMarkIcon className="size-4" />
          </button>
        )}
        <button
          tabIndex={-1}
          onMouseDown={handleChevronClick}
          className="shrink-0 cursor-pointer"
        >
          <ChevronDownIcon
            className={`size-4 text-gray-400 transition-transform ${isOpen ? 'rotate-180' : ''}`}
          />
        </button>
      </div>

      {isOpen && (
        <div className="absolute top-full left-0 right-0 mt-1 z-50 bg-white dark:bg-gray-800 rounded-md shadow-lg ring-1 ring-black/5 dark:ring-white/10 overflow-hidden">
          {loading ? (
            <div className="flex justify-center py-4">
              <div className="loading"><div></div></div>
            </div>
          ) : results.length === 0 ? (
            <div className="px-3 py-4 text-sm text-center text-gray-400 dark:text-gray-500">
              No results
            </div>
          ) : (
            <ul className="py-1">
              {results.slice(0, 10).map(({ step, visitors }, i) => {
                const barWidth = Math.round((visitors / maxVisitors) * 100)
                const isHighlighted = highlightedIndex === i
                return (
                  <li className="mb-1 last:mb-0" key={`${step.name}:${step.pathname}`}>
                    <button
                      tabIndex={-1}
                      className="flex items-center w-full text-left focus:outline-none"
                      onMouseEnter={() => setHighlightedIndex(i)}
                      onMouseDown={(e) => { e.preventDefault(); selectItem(step) }}
                    >
                      <div className="relative w-full mx-1 rounded-sm overflow-hidden">
                        <div
                          className={`absolute inset-y-0 left-0 ${isHighlighted ? 'bg-indigo-100 dark:bg-indigo-800/50' : 'bg-indigo-50 dark:bg-indigo-900/30'}`}
                          style={{ width: `${barWidth}%` }}
                        />
                        <div className="relative flex items-center justify-between px-2 py-1.5 gap-3">
                          <span className="truncate text-sm text-gray-800 dark:text-gray-200" title={step.label}>
                            {step.label}
                          </span>
                          <span className="shrink-0 text-sm text-gray-800 dark:text-gray-200">
                            {numberShortFormatter(visitors)}
                          </span>
                        </div>
                      </div>
                    </button>
                  </li>
                )
              })}
            </ul>
          )}
        </div>
      )}
    </div>
  )
}

const ExplorationColumn = React.forwardRef(function ExplorationColumn({
  header,
  steps,
  selected,
  selectedVisitors,
  selectedConversionRate,
  onSelect,
  dashboardState,
  direction,
  autoOpen = false,
  skipAutoOpen = false,
  onSuggestJourney = null,
  isSuggestingJourney = false
}, ref) {
  const conversionRate =
    selectedConversionRate !== null ? selectedConversionRate : 100

  const funnelHeight = Math.max(Math.round((conversionRate / 100) * 360), 20)

  return (
    <div ref={ref} className="min-w-80 flex flex-col flex-1 gap-1.5 p-2 bg-gray-50 dark:bg-gray-800 rounded-lg">
      <span className="text-xs font-medium text-gray-500 dark:text-gray-400">
        {header}
      </span>

      <ExplorationStepCombobox
        steps={steps ?? []}
        dashboardState={dashboardState}
        direction={direction}
        onSelect={onSelect}
        disabled={steps === null}
        selectedLabel={selected?.label ?? null}
        autoOpen={autoOpen}
        skipAutoOpen={skipAutoOpen}
      />

      <div className={`mt-3 h-[360px] flex flex-col gap-1.5 ${selected ? 'justify-end' : ''}`}>
        {!selected && steps !== null && steps.length === 0 && (
          <div className="rounded-md bg-indigo-100/70 dark:bg-indigo-900/30 px-3.5 py-3 text-sm text-gray-800 dark:text-gray-200">
            {isSuggestingJourney ? (
              <p className="flex items-center gap-1.5">
                <svg className="animate-spin size-3.5 text-indigo-600 dark:text-indigo-400 shrink-0" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                </svg>
                Finding a suggested path…
              </p>
            ) : (
              <p>
                Select a starting point in the search field above or start with a{' '}
                <button onClick={onSuggestJourney} className="text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300">suggested path</button>
                <span className="relative group inline-flex align-middle ml-1">
                  <InformationCircleIcon className="mb-0.5 size-4 text-indigo-600 dark:text-indigo-400 cursor-default" />
                  <span className="pointer-events-none absolute bottom-full left-1/2 -translate-x-1/2 mb-1.5 w-48 rounded-sm bg-gray-800 dark:bg-gray-700 px-2 py-1 text-xs text-gray-100 font-medium opacity-0 group-hover:opacity-100 transition-opacity duration-150 text-center z-10">
                    A representative path based on common user behavior.
                  </span>
                </span>
              </p>
            )}
          </div>
        )}
        {selected && (
          <>
            <div className="flex items-baseline justify-between gap-1.5 flex-wrap min-w-0 px-1">
              <span
                className="text-sm text-gray-800 dark:text-gray-200 truncate"
                title={selected.label}
              >
                {selected.label}
              </span>
              <div className="flex items-center gap-1.5">
                <span className="font-medium text-sm text-gray-800 dark:text-gray-200 shrink-0">
                  {numberShortFormatter(selectedVisitors ?? 0)}
                </span>
                <span className="py-0.5 px-1 bg-white border border-gray-200 dark:border-gray-700 rounded-md text-xs font-semibold text-indigo-600 dark:text-indigo-400 shrink-0">
                  {conversionRate}%
                </span>
              </div>
            </div>
            <div
              className="w-full rounded-lg bg-indigo-100 dark:bg-indigo-800/60 transition-[height] duration-300 ease-in-out"
              style={{ height: `${funnelHeight}px` }}
            />
          </>
        )}
      </div>
    </div>
  )
})

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
  // suppresses auto-open on the next empty column when steps were pre-filled
  const stepsSuggestedRef = useRef(false)

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
          stepsSuggestedRef.current = true
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
    stepsSuggestedRef.current = false

    if (selected === null) {
      setSteps(steps.slice(0, columnIndex))
    } else {
      setSteps([...steps.slice(0, columnIndex), selected])
    }
  }

  function handleReset() {
    handleSelect(0, null)
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

    if (stepsSuggestedRef.current) return

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
  const columnRefs = useRef([])

  useEffect(() => {
    if (steps.length === 0) return
    const timer = setTimeout(() => {
      const container = scrollRef.current
      const column = columnRefs.current[steps.length]
      if (!container || !column) return
      const containerRight = container.getBoundingClientRect().right
      const columnRight = column.getBoundingClientRect().right
      const delta = columnRight - containerRight
      if (delta > 0) {
        container.scrollTo({ left: container.scrollLeft + delta, behavior: 'smooth' })
      }
    }, 50)
    return () => clearTimeout(timer)
  }, [steps.length])

  return (
    <div className="flex flex-col gap-5 pt-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-col">
          <h4 className="text-base font-semibold dark:text-gray-100">
            New funnel
          </h4>
          {steps.length >= 2 && funnel.length >= 2 ? (
            <p className="text-sm text-gray-500 dark:text-gray-400">
              {steps.length}-step funnel • {funnel[funnel.length - 1].conversion_rate}% conversion rate • <button onClick={handleReset} className="text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300">Reset</button>
            </p>
          ) : (
            <p className="text-sm text-gray-500 dark:text-gray-400">
              Explore user journeys and save them as funnels
            </p>
          )}
        </div>
        <div className="flex shrink-0 items-center gap-3">
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

      <div ref={scrollRef} style={{ scrollBehavior: 'smooth' }} className="flex gap-4 overflow-x-auto -mx-5 px-5 -mb-3 pb-3">
        {Array.from({ length: numColumns }, (_, i) => (
          <ExplorationColumn
            key={i}
            ref={(el) => { columnRefs.current[i] = el }}
            header={columnHeader(i, direction)}
            steps={steps.length >= i ? steps.slice(0, i) : null}
            selected={steps[i]}
            selectedVisitors={funnel[i]?.visitors ?? null}
            selectedConversionRate={funnel[i]?.conversion_rate ?? null}
            onSelect={(selected) => handleSelect(i, selected)}
            dashboardState={dashboardState}
            direction={direction}
            autoOpen={i === steps.length && steps.length > 0}
            skipAutoOpen={stepsSuggestedRef.current}
            onSuggestJourney={i === 0 ? handleSuggestJourney : null}
            isSuggestingJourney={i === 0 ? isSuggestingJourney : false}
          />
        ))}
      </div>
    </div>
  )
}

export default FunnelExploration
