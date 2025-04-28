import { Popover, Transition } from '@headlessui/react'
import classNames from 'classnames'
import React, { ReactNode, useRef } from 'react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import { popover, BlurMenuButtonOnEscape } from './popover'
import { useSearchableItems } from '../hooks/use-searchable-items'
import { SearchInput } from './search-input'
import { EllipsisHorizontalIcon } from '@heroicons/react/24/solid'

export const TabWrapper = ({
  className,
  children
}: {
  className?: string
  children: ReactNode
}) => (
  <div
    className={classNames(
      'flex text-xs font-medium text-gray-500 dark:text-gray-400 space-x-2 items-baseline',
      className
    )}
  >
    {children}
  </div>
)

const TabButtonText = ({
  children,
  active
}: {
  children: ReactNode
  active: boolean
}) => (
  <span
    className={classNames('truncate text-left', {
      'hover:text-indigo-600 cursor-pointer': !active,
      'text-indigo-700 dark:text-indigo-500 font-bold underline decoration-2 decoration-indigo-700 dark:decoration-indigo-500':
        active
    })}
  >
    {children}
  </span>
)

export const TabButton = ({
  className,
  children,
  onClick,
  active
}: {
  className?: string
  children: ReactNode
  onClick: () => void
  active: boolean
}) => (
  <button className={classNames('rounded-sm', className)} onClick={onClick}>
    <TabButtonText active={active}>{children}</TabButtonText>
  </button>
)

export const DropdownTabButton = ({
  className,
  transitionClassName,
  active,
  children,
  options,
  searchable,
  collectionTitle
}: {
  className?: string
  transitionClassName?: string
  active: boolean
  children: ReactNode
  options: Array<{ selected: boolean; onClick: () => void; label: string }>
  searchable?: boolean
  collectionTitle?: string
}) => {
  const dropdownButtonRef = useRef<HTMLButtonElement>(null)
  const {
    filteredData,
    showableData,
    showSearch,
    searching,
    searchRef,
    handleSearchInput,
    handleClearSearch,
    handleShowAll,
    countOfMoreToShow
  } = useSearchableItems({
    data: options,
    maxItemsInitially: searchable ? 5 : options.length,
    itemMatchesSearchValue: (option, trimmedSearchString) =>
      option.label.toLowerCase().includes(trimmedSearchString.toLowerCase())
  })

  const itemClassName = classNames(
    'w-full text-left',
    popover.items.classNames.navigationLink,
    popover.items.classNames.selectedOption,
    popover.items.classNames.hoverLink,
    { [popover.items.classNames.roundedStart]: !searchable },
    popover.items.classNames.roundedEnd
  )

  return (
    <Popover className={className}>
      {({ close: closeDropdown }) => (
        <>
          <BlurMenuButtonOnEscape targetRef={dropdownButtonRef} />
          <Popover.Button
            className={classNames('inline-flex justify-between rounded-sm')}
            ref={dropdownButtonRef}
          >
            <TabButtonText active={active}>{children}</TabButtonText>

            <div
              className="flex self-stretch -mr-1 ml-1 items-center"
              aria-hidden="true"
            >
              <ChevronDownIcon className="h-4 w-4" />
            </div>
          </Popover.Button>

          <Transition
            as="div"
            {...popover.transition.props}
            className={classNames(
              popover.transition.classNames.fullwidth,
              'mt-2',
              transitionClassName
            )}
          >
            <Popover.Panel className={popover.panel.classNames.roundedSheet}>
              {searchable && showSearch && (
                <div className="flex items-center py-2 px-4">
                  {collectionTitle && (
                    <div className="text-sm font-bold uppercase text-indigo-500 dark:text-indigo-400 mr-4">
                      {collectionTitle}
                    </div>
                  )}
                  <SearchInput
                    searchRef={searchRef}
                    placeholderUnfocused="Press / to search"
                    className="ml-auto w-full py-1 text-sm"
                    onSearch={handleSearchInput}
                  />
                </div>
              )}
              <div className={'max-h-[210px] overflow-y-scroll'}>
                {showableData.map(({ selected, label, onClick }, index) => {
                  return (
                    <button
                      key={index}
                      onClick={() => {
                        onClick()
                        closeDropdown()
                      }}
                      data-selected={selected}
                      className={itemClassName}
                    >
                      {label}
                    </button>
                  )
                })}
                {countOfMoreToShow > 0 && (
                  <button
                    onClick={handleShowAll}
                    className={classNames(
                      itemClassName,
                      'w-full text-left font-bold hover:text-indigo-700 dark:hover:text-indigo-500'
                    )}
                  >
                    {`Show ${countOfMoreToShow} more`}
                    <EllipsisHorizontalIcon className="block w-5 h-5" />
                  </button>
                )}
                {searching && !filteredData.length && (
                  <button
                    className={classNames(
                      itemClassName,
                      'w-full text-left font-bold hover:text-indigo-700 dark:hover:text-indigo-500'
                    )}
                    onClick={handleClearSearch}
                  >
                    No items found. Clear search to show all.
                  </button>
                )}
              </div>
            </Popover.Panel>
          </Transition>
        </>
      )}
    </Popover>
  )
}
