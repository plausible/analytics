import React, { useEffect, useId, useRef, useState } from 'react'
import classNames from 'classnames'
import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { useDashboardStateContext } from '../dashboard-state-context'
import {
  fetchSuggestions,
  Suggestion,
  SuggestionsRequest
} from '../util/fetch-suggestions'
import { Spinner } from './icons'
import { popover } from './popover'
import { SearchInput } from './search-input'
import { checkboxClassName } from './form-elements'

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
      <SearchInput
        searchRef={inputRef}
        className="!max-w-none"
        value={input}
        onChange={(value) => {
          setInput(value)
          setHighlightedIndex(0)
        }}
        onSearch={setSearch}
        inputProps={{
          role: 'combobox',
          'aria-label': label,
          'aria-expanded': options.length > 0,
          'aria-controls': listboxId,
          'aria-autocomplete': 'list',
          'aria-activedescendant':
            activeIndex >= 0 ? optionId(activeIndex) : undefined,
          onKeyDown
        }}
        trailing={
          !!request &&
          suggestionsQuery.isFetching && (
            <Spinner className="animate-spin size-4 text-indigo-500" />
          )
        }
      />
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
                popover.items.classNames.staticRow,
                'flex items-center gap-x-2 select-none',
                disabled
                  ? 'cursor-default text-gray-400 dark:text-gray-500'
                  : 'cursor-pointer',
                index === activeIndex &&
                  !disabled &&
                  popover.items.classNames.highlightedOption
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
                  className={checkboxClassName({
                    size: 'sm',
                    className: 'pointer-events-none'
                  })}
                />
              )}
              <span className={popover.items.classNames.label} title={text}>
                {text}
              </span>
            </li>
          )
        })}
      </ul>
      {statusMessage && (
        <div
          className={classNames(
            popover.items.classNames.staticRow,
            'text-gray-500 dark:text-gray-400'
          )}
        >
          {statusMessage}
        </div>
      )}
    </div>
  )
}
