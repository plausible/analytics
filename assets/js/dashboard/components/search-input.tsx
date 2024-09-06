/** @format */

import React, { ChangeEventHandler, useCallback, useRef } from 'react'
import { isModifierPressed, Keybind } from '../keybinding'
import { useDebounce } from '../custom-hooks'

export const SearchInput = ({
  onSearch
}: {
  onSearch: (value: string) => void
}) => {
  const onSearchInputChange: ChangeEventHandler<HTMLInputElement> = useCallback(
    (event) => {
      onSearch(event.target.value)
    },
    [onSearch]
  )
  const debouncedOnSearchInputChange = useDebounce(onSearchInputChange)

  const searchBoxRef = useRef<HTMLInputElement>(null)

  const blurSearchBox = useCallback((event: KeyboardEvent) => {
    const searchBox = searchBoxRef.current
    if (
      searchBox?.contains(event.target as HTMLElement)
    ) {
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
        className="shadow-sm dark:bg-gray-900 dark:text-gray-100 focus:ring-indigo-500 focus:border-indigo-500 block sm:text-sm border-gray-300 dark:border-gray-500 rounded-md dark:bg-gray-800 w-48"
        onChange={debouncedOnSearchInputChange}
      />
    </>
  )
}
