/** @format */

import React, { ChangeEventHandler, useCallback, useRef } from 'react'
import { isModifierPressed, Keybind } from '../keybinding'
import { useDebounce } from '../custom-hooks'
import classNames from 'classnames'

export const SearchInput = ({
  onSearch,
  className
}: {
  className?: string
  onSearch: (value: string) => void
}) => {
  const searchBoxRef = useRef<HTMLInputElement>(null)

  const onSearchInputChange: ChangeEventHandler<HTMLInputElement> = useCallback(
    (event) => {
      onSearch(event.target.value)
    },
    [onSearch]
  )
  const debouncedOnSearchInputChange = useDebounce(onSearchInputChange)

  const blurSearchBox = useCallback((event: KeyboardEvent) => {
    const searchBox = searchBoxRef.current
    if (searchBox?.contains(event.target as HTMLElement)) {
      searchBox.blur()
      event.stopPropagation()
    }
  }, [])

  return (
    <>
      <Keybind
        keyboardKey="Escape"
        type="keyup"
        handler={blurSearchBox}
        shouldIgnoreWhen={[isModifierPressed]}
      />
      <input
        ref={searchBoxRef}
        type="text"
        placeholder="Search"
        className={classNames(
          'shadow-sm dark:bg-gray-900 dark:text-gray-100 focus:ring-indigo-500 focus:border-indigo-500 block sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:bg-gray-800 w-48',
          className
        )}
        onChange={debouncedOnSearchInputChange}
      />
    </>
  )
}
