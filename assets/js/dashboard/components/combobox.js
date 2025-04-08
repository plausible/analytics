import React, {
  Fragment,
  useState,
  useCallback,
  useEffect,
  useRef
} from 'react'
import { Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import { useMountedEffect, useDebounce } from '../custom-hooks'

function Option({ isHighlighted, onClick, onMouseEnter, text, id }) {
  const className = classNames(
    'relative cursor-pointer select-none py-2 px-3',
    {
      'text-gray-900 dark:text-gray-300': !isHighlighted,
      'bg-indigo-600 text-white': isHighlighted
    }
  )

  return (
    // eslint-disable-next-line jsx-a11y/no-noninteractive-element-interactions
    <li
      className={className}
      id={id}
      onClick={onClick}
      onMouseEnter={onMouseEnter}
    >
      <span className="block truncate">{text}</span>
    </li>
  )
}
function scrollTo(wrapper, id) {
  if (wrapper) {
    const el = wrapper.querySelector('#' + id)

    if (el) {
      el.scrollIntoView({ block: 'center' })
    }
  }
}

function optionId(index) {
  return `plausible-combobox-option-${index}`
}

export default function PlausibleCombobox({
  values,
  fetchOptions,
  singleOption,
  isDisabled,
  autoFocus,
  freeChoice,
  disabledOptions,
  onSelect,
  placeholder,
  forceLoading,
  className,
  boxClass
}) {
  const isEmpty = values.length === 0
  const [options, setOptions] = useState([])
  const [isLoading, setLoading] = useState(false)
  const [isOpen, setOpen] = useState(false)
  const [search, setSearch] = useState('')
  const [highlightedIndex, setHighlightedIndex] = useState(0)
  const searchRef = useRef(null)
  const containerRef = useRef(null)
  const listRef = useRef(null)

  const loading = isLoading || !!forceLoading

  const visibleOptions = [...options]
  if (
    freeChoice &&
    search.length > 0 &&
    options.every((option) => option.value !== search)
  ) {
    visibleOptions.push({ value: search, label: search, freeChoice: true })
  }

  const afterFetchOptions = useCallback((loadedOptions) => {
    setLoading(false)
    setHighlightedIndex(0)
    setOptions(loadedOptions)
  }, [])

  const initialFetchOptions = useCallback(() => {
    setLoading(true)
    fetchOptions('').then(afterFetchOptions)
  }, [fetchOptions, afterFetchOptions])

  const searchOptions = useCallback(() => {
    if (isOpen) {
      setLoading(true)
      fetchOptions(search).then(afterFetchOptions)
    }
  }, [search, isOpen, fetchOptions, afterFetchOptions])

  const debouncedSearchOptions = useDebounce(searchOptions)

  useEffect(() => {
    if (isOpen) {
      initialFetchOptions()
    }
  }, [isOpen, initialFetchOptions])

  useMountedEffect(() => {
    debouncedSearchOptions()
  }, [search])

  function highLight(index) {
    let newIndex = index

    if (index < 0) {
      newIndex = visibleOptions.length - 1
    } else if (index >= visibleOptions.length) {
      newIndex = 0
    }

    setHighlightedIndex(newIndex)
    scrollTo(listRef.current, optionId(newIndex))
  }

  function onKeyDown(e) {
    if (e.key === 'Enter') {
      if (!isOpen || loading || visibleOptions.length === 0) return null
      selectOption(visibleOptions[highlightedIndex])
      e.preventDefault()
    }
    if (e.key === 'Escape') {
      if (!isOpen || loading) return null
      setOpen(false)
      searchRef.current?.focus()
      e.preventDefault()
    }
    if (e.key === 'ArrowDown') {
      if (isOpen) {
        highLight(highlightedIndex + 1)
      } else {
        setOpen(true)
      }
    }
    if (e.key === 'ArrowUp') {
      if (isOpen) {
        highLight(highlightedIndex - 1)
      } else {
        setOpen(true)
      }
    }
  }

  function isOptionDisabled(option) {
    const optionAlreadySelected = values.some(
      (val) => val.value === option.value
    )
    const optionDisabled = (disabledOptions || []).some(
      (val) => val?.value === option.value
    )
    return optionAlreadySelected || optionDisabled
  }

  function onInput(e) {
    if (!isOpen) {
      setOpen(true)
    }
    setSearch(e.target.value)
  }

  function toggleOpen() {
    if (!isOpen) {
      setOpen(true)
      searchRef.current.focus()
    } else {
      setSearch('')
      setOpen(false)
    }
  }

  function selectOption(option) {
    if (singleOption) {
      onSelect([option])
    } else {
      searchRef.current.focus()
      onSelect([...values, option])
    }

    setOpen(false)
    setSearch('')
  }

  function removeOption(option, e) {
    e.stopPropagation()
    const newValues = values.filter((val) => val.value !== option.value)
    onSelect(newValues)
    searchRef.current.focus()
    setOpen(false)
  }

  const handleClick = useCallback((e) => {
    if (containerRef.current && containerRef.current.contains(e.target)) {
      return
    }

    setSearch('')
    setOpen(false)
  }, [])

  useEffect(() => {
    document.addEventListener('mousedown', handleClick, false)
    return () => {
      document.removeEventListener('mousedown', handleClick, false)
    }
  }, [handleClick])

  useEffect(() => {
    if (singleOption && isEmpty && autoFocus) {
      searchRef.current.focus()
    }
  }, [isEmpty, singleOption, autoFocus])

  const searchBoxClass =
    'border-none py-1 px-0 w-full inline-block rounded-md focus:outline-none focus:ring-0 text-sm'

  const containerClass = classNames('relative w-full', {
    [className]: !!className,
    'opacity-30 cursor-default pointer-events-none': isDisabled
  })

  function renderSingleOptionContent() {
    const itemSelected = values.length === 1

    return (
      <div className="flex items-center truncate">
        {itemSelected && renderSingleSelectedItem()}
        <input
          className={searchBoxClass}
          ref={searchRef}
          value={search}
          style={{ backgroundColor: 'inherit' }}
          placeholder={itemSelected ? '' : placeholder}
          type="text"
          onChange={onInput}
        ></input>
      </div>
    )
  }

  function renderSingleSelectedItem() {
    if (search === '') {
      return (
        <span className="dark:text-gray-300 text-sm w-0">
          {values[0].label}
        </span>
      )
    }
  }

  function renderMultiOptionContent() {
    return (
      <>
        {values.map((value) => {
          return (
            <div
              key={value.value}
              className="bg-indigo-100 dark:bg-indigo-600 flex justify-between w-full rounded-sm px-2 py-0.5 m-0.5 text-sm"
            >
              <span className="break-all">{value.label}</span>
              <span
                onClick={(e) => removeOption(value, e)}
                className="cursor-pointer font-bold ml-1"
              >
                &times;
              </span>
            </div>
          )
        })}
        <input
          className={searchBoxClass}
          ref={searchRef}
          value={search}
          style={{ backgroundColor: 'inherit' }}
          placeholder={placeholder}
          type="text"
          onChange={onInput}
        ></input>
      </>
    )
  }

  function renderDropDownContent() {
    const matchesFound =
      visibleOptions.length > 0 &&
      visibleOptions.some((option) => !isOptionDisabled(option))

    if (loading) {
      return (
        <div className="relative cursor-default select-none py-2 px-4 text-gray-700 dark:text-gray-300">
          Loading options...
        </div>
      )
    }

    if (matchesFound) {
      return visibleOptions
        .filter((option) => !isOptionDisabled(option))
        .map((option, i) => {
          const text = option.freeChoice
            ? `Filter by '${option.label}'`
            : option.label

          return (
            <Option
              key={option.value}
              id={optionId(i)}
              isHighlighted={highlightedIndex === i}
              onClick={() => selectOption(option)}
              onMouseEnter={() => setHighlightedIndex(i)}
              text={text}
            />
          )
        })
    }

    if (freeChoice) {
      return (
        <div className="relative cursor-default select-none py-2 px-4 text-gray-700 dark:text-gray-300">
          Start typing to apply filter
        </div>
      )
    }

    return (
      <div className="relative cursor-default select-none py-2 px-4 text-gray-700 dark:text-gray-300">
        No matches found in the current dashboard. Try selecting a different
        time range or searching for something different
      </div>
    )
  }

  const defaultBoxClass =
    'pl-2 pr-8 py-1 w-full dark:bg-gray-900 dark:text-gray-300 rounded-md shadow-sm border border-gray-300 dark:border-gray-700 focus-within:border-indigo-500 focus-within:ring-1 focus-within:ring-indigo-500'
  const finalBoxClass = classNames(boxClass || defaultBoxClass, {
    'border-indigo-500 ring-1 ring-indigo-500': isOpen
  })

  return (
    <div onKeyDown={onKeyDown} ref={containerRef} className={containerClass}>
      <div onClick={toggleOpen} className={finalBoxClass}>
        {singleOption && renderSingleOptionContent()}
        {!singleOption && renderMultiOptionContent()}
        <div className="cursor-pointer absolute inset-y-0 right-0 flex items-center pr-2">
          {!loading && <ChevronDownIcon className="h-4 w-4 text-gray-500" />}
          {loading && <Spinner />}
        </div>
      </div>
      {isOpen && (
        <Transition
          as={Fragment}
          leave="transition ease-in duration-100"
          leaveFrom="opacity-100"
          leaveTo="opacity-0"
          show={isOpen}
        >
          <ul
            ref={listRef}
            className="z-50 absolute mt-1 max-h-60 w-full overflow-auto rounded-md bg-white py-1 text-base shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none sm:text-sm dark:bg-gray-900"
          >
            {renderDropDownContent()}
          </ul>
        </Transition>
      )}
    </div>
  )
}

function Spinner() {
  return (
    <svg
      className="animate-spin h-4 w-4 text-indigo-500"
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
    >
      <circle
        className="opacity-25"
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        strokeWidth="4"
      ></circle>
      <path
        className="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
      ></path>
    </svg>
  )
}
