import React, {
  ChangeEventHandler,
  InputHTMLAttributes,
  ReactNode,
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
  value,
  onChange,
  inputProps,
  trailing,
  className,
  placeholderFocusedOrMobile = 'Search',
  placeholderUnfocusedOnlyDesktop = 'Press / to search'
}: {
  searchRef: RefObject<HTMLInputElement>
  /** Called with a debounce */
  onSearch: (value: string) => void
  value?: string
  /** Called at once on every change */
  onChange?: (value: string) => void
  inputProps?: Omit<
    InputHTMLAttributes<HTMLInputElement>,
    | 'value'
    | 'onChange'
    | 'onFocus'
    | 'onBlur'
    | 'type'
    | 'placeholder'
    | 'className'
  >
  trailing?: ReactNode
  className?: string
  placeholderFocusedOrMobile?: string
  placeholderUnfocusedOnlyDesktop?: string
}) => {
  const [isFocused, setIsFocused] = useState(false)
  const [uncontrolledHasValue, setUncontrolledHasValue] = useState(false)
  const hasValue = value === undefined ? uncontrolledHasValue : value !== ''

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
      setUncontrolledHasValue(value.length > 0)
      onChange?.(value)
      debouncedOnSearchInputChange(event)
    },
    [onChange, debouncedOnSearchInputChange]
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
      <div
        className={classNames(
          'relative flex items-center max-w-64 w-full rounded-md border border-gray-300 dark:border-gray-750 bg-white dark:bg-gray-750 focus-within:border-indigo-500 focus-within:ring-3 focus-within:ring-indigo-500/20 dark:focus-within:ring-indigo-500/25',
          className
        )}
      >
        <input
          data-testid="search-input"
          {...inputProps}
          onBlur={() => setIsFocused(false)}
          onFocus={() => setIsFocused(true)}
          ref={searchRef}
          type="text"
          placeholder=" "
          className="peer flex-1 min-w-0 border-none bg-transparent px-3 py-1.5 text-sm dark:text-gray-100 focus:outline-none focus:ring-0"
          value={value}
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
        {trailing && <div className="flex shrink-0 pr-3">{trailing}</div>}
      </div>
    </>
  )
}
