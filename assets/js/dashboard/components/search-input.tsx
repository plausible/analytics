import React, { ChangeEventHandler, useCallback, useState, useRef } from 'react'
import { isModifierPressed, Keybind } from '../keybinding'
import { useDebounce } from '../custom-hooks'
import classNames from 'classnames'

export const SearchInput = ({
  onSearch,
  className,
  placeholderFocused = 'Search',
  placeholderUnfocused = 'Press / to search'
}: {
  onSearch: (value: string) => void
  className?: string
  placeholderFocused?: string
  placeholderUnfocused?: string
}) => {
  const searchBoxRef = useRef<HTMLInputElement>(null)
  const [isFocused, setIsFocused] = useState(false)

  const onSearchInputChange: ChangeEventHandler<HTMLInputElement> = useCallback(
    (event) => {
      onSearch(event.target.value)
    },
    [onSearch]
  )
  const debouncedOnSearchInputChange = useDebounce(onSearchInputChange)

  const blurSearchBox = useCallback(() => {
    searchBoxRef.current?.blur()
  }, [])

  const focusSearchBox = useCallback((event: KeyboardEvent) => {
    searchBoxRef.current?.focus()
    event.stopPropagation()
  }, [])

  return (
    <>
      <Keybind
        keyboardKey="Escape"
        type="keyup"
        handler={blurSearchBox}
        shouldIgnoreWhen={[isModifierPressed, () => !isFocused]}
        targetRef={searchBoxRef}
      />
      <Keybind
        keyboardKey="/"
        type="keyup"
        handler={focusSearchBox}
        shouldIgnoreWhen={[isModifierPressed, () => isFocused]}
        targetRef="document"
      />
      <input
        onBlur={() => setIsFocused(false)}
        onFocus={() => setIsFocused(true)}
        ref={searchBoxRef}
        type="text"
        placeholder={isFocused ? placeholderFocused : placeholderUnfocused}
        className={classNames(
          'shadow-sm dark:bg-gray-900 dark:text-gray-100 focus:ring-indigo-500 focus:border-indigo-500 block border-gray-300 dark:border-gray-500 rounded-md dark:bg-gray-800 w-48',
          className
        )}
        onChange={debouncedOnSearchInputChange}
      />
    </>
  )
}
