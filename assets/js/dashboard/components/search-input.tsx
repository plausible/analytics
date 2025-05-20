import React, {
  ChangeEventHandler,
  useCallback,
  useState,
  RefObject
} from 'react'
import { isModifierPressed, Keybind } from '../keybinding'
import { useDebounce } from '../custom-hooks'
import classNames from 'classnames'

export const SearchInput = ({
  searchRef,
  onSearch,
  className,
  placeholderFocused = 'Search',
  placeholderUnfocused = 'Press / to search'
}: {
  searchRef: RefObject<HTMLInputElement>
  onSearch: (value: string) => void
  className?: string
  placeholderFocused?: string
  placeholderUnfocused?: string
}) => {
  const [isFocused, setIsFocused] = useState(false)

  const onSearchInputChange: ChangeEventHandler<HTMLInputElement> = useCallback(
    (event) => {
      onSearch(event.target.value)
    },
    [onSearch]
  )
  const debouncedOnSearchInputChange = useDebounce(onSearchInputChange)

  const blurSearchBox = useCallback(() => {
    searchRef.current?.blur()
  }, [searchRef])

  const focusSearchBox = useCallback(
    (event: KeyboardEvent) => {
      searchRef.current?.focus()
      event.stopPropagation()
    },
    [searchRef]
  )

  return (
    <>
      <Keybind
        keyboardKey="Escape"
        type="keyup"
        handler={blurSearchBox}
        shouldIgnoreWhen={[isModifierPressed, () => !isFocused]}
        targetRef={searchRef}
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
        ref={searchRef}
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
