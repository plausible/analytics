import React, { useEffect, useId, useRef, useState } from 'react'
import classNames from 'classnames'
import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { useDashboardStateContext } from '../dashboard-state-context'
import {
  fetchSuggestions,
  Suggestion,
  SuggestionsRequest
} from '../util/fetch-suggestions'
import { useDebounce } from '../custom-hooks'
import { Spinner } from './icons'

export type ComboboxOption = Suggestion & { freeChoice?: boolean }

export const isSameValue = (a: Suggestion['value'], b: Suggestion['value']) =>
  String(a) === String(b)

const matchesSearch = (option: Suggestion, search: string) =>
  option.label.toLowerCase().includes(search.trim().toLowerCase())

export const Combobox = ({
  request,
  pinned = [],
  multiple = false,
  freeChoice = false,
  isSelected = () => false,
  isDisabled,
  onSelect,
  label,
  focusOnMount
}: {
  request: SuggestionsRequest | null
  /** Shown before the suggestions, and kept in place while the list is open */
  pinned?: Suggestion[]
  multiple?: boolean
  freeChoice?: boolean
  isSelected?: (option: Suggestion) => boolean
  isDisabled?: (option: Suggestion) => boolean
  onSelect: (option: ComboboxOption) => void
  label: string
  focusOnMount?: boolean
}) => {
  const { dashboardState } = useDashboardStateContext()
  // keeps the suggestions the same while the selected values change the dashboard
  const [initialDashboardState] = useState(dashboardState)
  const listboxId = useId()
  const inputRef = useRef<HTMLInputElement>(null)
  const listRef = useRef<HTMLUListElement>(null)
  const [input, setInput] = useState('')
  const [search, setSearch] = useState('')
  const [highlightedIndex, setHighlightedIndex] = useState(0)
  const debouncedSetSearch = useDebounce(setSearch)

  useEffect(() => {
    if (focusOnMount) {
      inputRef.current?.focus({ preventScroll: true })
    }
  }, [focusOnMount])

  const suggestionsQuery = useQuery({
    queryKey: [
      'filter-suggestions',
      request?.path,
      request?.additionalFilter,
      search.trim(),
      initialDashboardState
    ],
    queryFn: () =>
      fetchSuggestions(
        request!.path,
        initialDashboardState,
        search,
        request!.additionalFilter
      ),
    enabled: !!request,
    placeholderData: keepPreviousData
  })

  const trimmedInput = input.trim()
  const pinnedOptions = pinned.filter((option) =>
    matchesSearch(option, trimmedInput)
  )
  const suggestedOptions = (
    request ? (suggestionsQuery.data ?? []) : []
  ).filter((option) => !pinned.some((p) => isSameValue(p.value, option.value)))
  const freeChoiceOptions: ComboboxOption[] =
    freeChoice &&
    trimmedInput.length > 0 &&
    ![...pinned, ...suggestedOptions].some((option) =>
      isSameValue(option.value, trimmedInput)
    )
      ? [{ value: trimmedInput, label: trimmedInput, freeChoice: true }]
      : []
  const options: ComboboxOption[] = [
    ...freeChoiceOptions,
    ...pinnedOptions,
    ...suggestedOptions
  ]
  const activeIndex = Math.min(highlightedIndex, options.length - 1)

  const optionId = (index: number) => `${listboxId}-option-${index}`

  const highlight = (index: number) => {
    const wrapped = (index + options.length) % options.length
    setHighlightedIndex(wrapped)
    listRef.current
      ?.querySelector(`[id="${optionId(wrapped)}"]`)
      ?.scrollIntoView?.({ block: 'nearest' })
  }

  const select = (option: ComboboxOption | undefined) => {
    if (!option || isDisabled?.(option)) {
      return
    }
    if (option.freeChoice) {
      setInput('')
      setSearch('')
    }
    onSelect(option)
  }

  const onKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
    if (!options.length) {
      return
    }
    if (event.key === 'ArrowDown') {
      event.preventDefault()
      highlight(activeIndex + 1)
    } else if (event.key === 'ArrowUp') {
      event.preventDefault()
      highlight(Math.max(activeIndex, 0) - 1)
    } else if (event.key === 'Enter') {
      event.preventDefault()
      select(options[activeIndex])
    }
  }

  const isLoading = !!request && suggestionsQuery.isPending

  const getStatusMessage = () => {
    if (isLoading) {
      return 'Loading options...'
    }
    if (options.length) {
      return null
    }
    if (freeChoice) {
      return 'Start typing to apply filter'
    }
    return 'No matches found in the current dashboard. Try selecting a different time range or searching for something different'
  }
  const statusMessage = getStatusMessage()

  return (
    <div className="flex flex-col gap-y-1">
      <div className="flex items-center gap-x-2 rounded-md border border-gray-300 dark:border-gray-750 dark:bg-gray-750 pr-2 focus-within:border-indigo-500 focus-within:ring-3 focus-within:ring-indigo-500/20 dark:focus-within:ring-indigo-500/25">
        <input
          ref={inputRef}
          type="text"
          role="combobox"
          aria-label={label}
          aria-expanded={options.length > 0}
          aria-controls={listboxId}
          aria-autocomplete="list"
          aria-activedescendant={
            activeIndex >= 0 ? optionId(activeIndex) : undefined
          }
          placeholder="Search..."
          className="flex-1 min-w-0 border-none bg-transparent px-2.5 py-1.5 text-sm dark:text-gray-100 dark:placeholder:text-gray-400 focus:outline-hidden focus:ring-0"
          value={input}
          onChange={(event) => {
            setInput(event.target.value)
            setHighlightedIndex(0)
            debouncedSetSearch(event.target.value)
          }}
          onKeyDown={onKeyDown}
        />
        {!!request && suggestionsQuery.isFetching && (
          <Spinner className="animate-spin size-4 shrink-0 text-indigo-500" />
        )}
      </div>
      <ul
        ref={listRef}
        id={listboxId}
        role="listbox"
        aria-label={label}
        aria-multiselectable={multiple || undefined}
        className="flex flex-col gap-y-0.5 max-h-60 overflow-y-auto empty:hidden"
        onMouseLeave={() => setHighlightedIndex(-1)}
      >
        {options.map((option, index) => {
          const selected = isSelected(option)
          const disabled = !!isDisabled?.(option)
          const text = option.freeChoice
            ? `Filter by '${option.label}'`
            : option.label
          return (
            <li
              key={`${option.freeChoice ? 'free' : 'option'}-${option.value}`}
              id={optionId(index)}
              role="option"
              aria-selected={selected}
              aria-disabled={disabled || undefined}
              className={classNames(
                'flex items-center gap-x-2 px-3 py-2 text-sm rounded-md select-none',
                disabled
                  ? 'cursor-default text-gray-400 dark:text-gray-500'
                  : 'cursor-pointer',
                index === activeIndex &&
                  !disabled &&
                  'bg-gray-100 text-gray-900 dark:bg-gray-700 dark:text-gray-100'
              )}
              onMouseEnter={() => setHighlightedIndex(index)}
              onMouseDown={(event) => event.preventDefault()}
              onClick={() => select(option)}
            >
              {multiple && (
                <input
                  type="checkbox"
                  tabIndex={-1}
                  aria-hidden="true"
                  readOnly
                  checked={selected}
                  className="block size-4 shrink-0 rounded-sm pointer-events-none dark:bg-gray-600 border-gray-300 dark:border-gray-600 text-indigo-600"
                />
              )}
              <span className="flex-1 min-w-0 truncate" title={text}>
                {text}
              </span>
            </li>
          )
        })}
      </ul>
      {statusMessage && (
        <div className="px-3 py-2 text-sm text-gray-500 dark:text-gray-400">
          {statusMessage}
        </div>
      )}
    </div>
  )
}
