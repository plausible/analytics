import React, { Fragment, useState, useCallback } from 'react'
import { Combobox, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import debounce from 'debounce-promise'

function Spinner() {
  return (
    <svg className="animate-spin h-4 w-4 text-indigo-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
  )
}

export default function PlausibleCombobox(props) {
  const [options, setOptions] = useState([])
  const [loading, setLoading] = useState(false)

  function fetchOptions(query) {
    setLoading(true)

    return props.fetchOptions(query).then((loadedOptions) => {
      setLoading(false)
      setOptions(loadedOptions)
    })
  }

  const debouncedFetchOptions = useCallback(debounce(fetchOptions, 200), [])

  function onOpen() {
    setOptions([])
    fetchOptions(props.selection.label)
  }

  function onBlur(e) {
    !props.strict && props.onChange({
      value: e.target.value,
      label: e.target.value
    })
  }


  function renderOptions() {
    if (loading) {
      return (
        <div className="relative cursor-default select-none py-2 px-4 text-gray-700 dark:text-gray-300">
          Loading options...
        </div>
      )
    } else if (!loading && options.length === 0) {
      return (
        <div className="relative cursor-default select-none py-2 px-4 text-gray-700 dark:text-gray-300">
          No matches found in the current dashboard. Try selecting a different time range or searching for something different
        </div>
      )

    } else {
      return options.map((option) => {
        return (
          <Combobox.Option
            key={option.value}
            className={({ active }) =>
              `relative cursor-default select-none py-2 px-3 ${active ? 'bg-indigo-600 text-white' : 'text-gray-900 dark:text-gray-300'
              }`
            }
            value={option}
          >
            <span className="block truncate">{option.label}</span>
          </Combobox.Option>
        )
      })
    }
  }

  return (
    <Combobox value={props.selection} onChange={(val) => props.onChange(val)}>
      <div className="relative ml-2 w-full">
        <Combobox.Button as="div" className="relative dark:bg-gray-900 dark:text-gray-300 block rounded-md shadow-sm border border-gray-300 dark:border-gray-700 hover:border-gray-400 dark:hover:border-gray-200 focus-within:ring-indigo-500 focus-within:border-indigo-500 ">
          <Combobox.Input
            className="border-none rounded-md focus:outline-none focus:ring-0 pr-10 text-sm"
            style={{backgroundColor: 'inherit'}}
            placeholder={props.placeholder}
            displayValue={(item) => item && item.label}
            onChange={(event) => debouncedFetchOptions(event.target.value)}
            onBlur={onBlur}
          />
          <div className="absolute inset-y-0 right-0 flex items-center pr-2">
            {!loading && <ChevronDownIcon className="h-4 w-4 text-gray-500" />}
            {loading && <Spinner />}
          </div>
        </Combobox.Button>
        <Transition
          as={Fragment}
          leave="transition ease-in duration-100"
          leaveFrom="opacity-100"
          leaveTo="opacity-0"
          beforeEnter={onOpen}
        >
          <Combobox.Options className="z-50 absolute mt-1 max-h-60 w-full overflow-auto rounded-md bg-white py-1 text-base shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none sm:text-sm dark:bg-gray-900">
            {renderOptions()}
          </Combobox.Options>
        </Transition>
      </div>
    </Combobox>
  )
}
