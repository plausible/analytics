import { Popover, Transition } from '@headlessui/react'
import classNames from 'classnames'
import React, { ReactNode, useRef, useEffect } from 'react'
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
      'flex items-baseline gap-x-3.5 text-xs font-medium text-gray-500 dark:text-gray-400',
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
    className={classNames('truncate text-left text-xs uppercase', {
      'text-gray-500 dark:text-gray-400 group-hover/tab:text-gray-800 dark:group-hover/tab:text-gray-200 font-semibold cursor-pointer':
        !active,
      'text-gray-900 dark:text-gray-100 font-bold tracking-[-.01em]': active
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
  <div
    className={classNames('-mb-px pb-4', {
      'border-b-2 border-gray-900 dark:border-gray-100': active
    })}
  >
    <button
      className={classNames('group/tab relative flex rounded-sm before:absolute before:inset-[-16px_-6px] before:content-[" "]', className)}
      onClick={onClick}
    >
      <TabButtonText active={active}>{children}</TabButtonText>
    </button>
  </div>
)

export const DropdownTabButton = ({
  className,
  transitionClassName,
  active,
  children,
  ...optionsProps
}: {
  className?: string
  transitionClassName?: string
  active: boolean
  children: ReactNode
} & Omit<ItemsProps, 'closeDropdown'>) => {
  const dropdownButtonRef = useRef<HTMLButtonElement>(null)

  return (
    <Popover className={className}>
      {({ close: closeDropdown }) => (
        <>
          <BlurMenuButtonOnEscape targetRef={dropdownButtonRef} />
          <div
            className={classNames('-mb-px pb-4', {
              'border-b-2 border-gray-900 dark:border-gray-100': active
            })}
          >
            <Popover.Button
              className="group/tab relative inline-flex justify-between rounded-xs before:absolute before:inset-[-16px_-6px] before:content-[' ']"
              ref={dropdownButtonRef}
            >
              <TabButtonText active={active}>{children}</TabButtonText>

              <div className="ml-0.5 -mr-1" aria-hidden="true">
                <ChevronDownIcon
                  className={classNames('size-4', {
                    'text-gray-500 dark:text-gray-400 group-hover/tab:text-gray-800 dark:group-hover/tab:text-gray-200':
                      !active,
                    'text-gray-900 dark:text-gray-100': active
                  })}
                />
              </div>
            </Popover.Button>
          </div>

          <Transition
            as="div"
            {...popover.transition.props}
            className={classNames(
              popover.transition.classNames.left,
              'mt-2',
              transitionClassName
            )}
          >
            <Popover.Panel className={popover.panel.classNames.roundedSheet}>
              <Items closeDropdown={closeDropdown} {...optionsProps} />
            </Popover.Panel>
          </Transition>
        </>
      )}
    </Popover>
  )
}

type ItemsProps = {
  closeDropdown: () => void
  options: Array<{ selected: boolean; onClick: () => void; label: string }>
  searchable?: boolean
}

const Items = ({ options, searchable, closeDropdown }: ItemsProps) => {
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
    maxItemsInitially: searchable ? 10 : options.length,
    itemMatchesSearchValue: (option, trimmedSearchString) =>
      option.label.toLowerCase().includes(trimmedSearchString.toLowerCase())
  })

  const itemClassName = classNames(
    'w-full text-left',
    popover.items.classNames.navigationLink,
    popover.items.classNames.selectedOption,
    popover.items.classNames.hoverLink
  )

  useEffect(() => {
    if (searchable && showSearch && searchRef.current) {
      const timeoutId = setTimeout(() => {
        searchRef.current?.focus()
      }, 100)
      return () => clearTimeout(timeoutId)
    }
  }, [searchable, showSearch, searchRef])

  return (
    <>
      {searchable && showSearch && (
        <div className="flex items-center p-1">
          <SearchInput
            searchRef={searchRef}
            className="!max-w-none"
            onSearch={handleSearchInput}
          />
        </div>
      )}
      <div
        className={'max-h-[224px] overflow-y-auto flex flex-col gap-y-0.5 p-1'}
      >
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
              <span className="line-clamp-1">{label}</span>
            </button>
          )
        })}
        {countOfMoreToShow > 0 && (
          <button
            onClick={handleShowAll}
            className={classNames(
              itemClassName,
              'w-full text-left text-gray-500 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200'
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
              'w-full text-left !justify-start'
            )}
            onClick={handleClearSearch}
          >
            No items found.{' '}
            <span className="ml-1 text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-500">
              Click to clear search.
            </span>
          </button>
        )}
      </div>
    </>
  )
}
