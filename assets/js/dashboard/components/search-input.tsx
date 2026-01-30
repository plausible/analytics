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
  placeholderFocusedOrMobile = 'Search',
  placeholderUnfocusedOnlyDesktop = 'Press / to search'
}: {
  searchRef: RefObject<HTMLInputElement>
  onSearch: (value: string) => void
  className?: string
  placeholderFocusedOrMobile?: string
  placeholderUnfocusedOnlyDesktop?: string
}) => {
  const [isFocused, setIsFocused] = useState(false)
  const [hasValue, setHasValue] = useState(false)

  const onSearchInputChange: ChangeEventHandler<HTMLInputElement> = useCallback(
    (event) => {
      onSearch(event.target.value)
    },
    [onSearch]
  )
  const debouncedOnSearchInputChange = useDebounce(onSearchInputChange)

  const handleInputChange: ChangeEventHandler<HTMLInputElement> = useCallback(
    (event) => {
      const value = event.target.value
      setHasValue(value.length > 0)
      debouncedOnSearchInputChange(event)
    },
    [debouncedOnSearchInputChange]
  )

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
      <div className={classNames('relative max-w-64 w-full', className)}>
        <input
          onBlur={() => setIsFocused(false)}
          onFocus={() => setIsFocused(true)}
          ref={searchRef}
          type="text"
          placeholder=" "
          className="peer w-full text-sm dark:text-gray-100 block border-gray-300 dark:border-gray-750 rounded-md dark:bg-gray-750 dark:placeholder:text-gray-400 focus:outline-none focus:ring-3 focus:ring-indigo-500/20 dark:focus:ring-indigo-500/25 focus:border-indigo-500"
          onChange={handleInputChange}
        />
        {!hasValue && (
          <>
            <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-sm text-gray-400 dark:text-gray-400 md:peer-[:not(:focus)]:hidden">
              {placeholderFocusedOrMobile}
            </span>
            <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-sm text-gray-400 dark:text-gray-400 hidden md:peer-[:not(:focus)]:block peer-focus:hidden">
              {placeholderUnfocusedOnlyDesktop}
            </span>
          </>
        )}
      </div>
    </>
  )
}
