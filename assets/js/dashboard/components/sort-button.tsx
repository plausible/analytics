import React, { ReactNode } from 'react'
import { cycleSortDirection, SortDirection } from '../hooks/use-order-by'
import classNames from 'classnames'

export const SortButton = ({
  children,
  toggleSort,
  sortDirection
}: {
  children: ReactNode
  toggleSort: () => void
  sortDirection: SortDirection | null
}) => {
  const next = cycleSortDirection(sortDirection)
  return (
    <button
      onClick={toggleSort}
      className={classNames('group', 'hover:text-gray-700 dark:hover:text-gray-200 transition-colors duration-100', 'relative')}
    >
      {children}
      <span
        title={next.hint}
        className={classNames(
          'absolute',
          'rounded inline-block size-4',
          'ml-1',
          {
            [SortDirection.asc]: 'rotate-180',
            [SortDirection.desc]: 'rotate-0'
          }[sortDirection ?? next.direction],
          !sortDirection && 'opacity-0',
          !sortDirection && 'group-hover:opacity-100',
          'group-hover:bg-gray-100 dark:group-hover:bg-gray-900',
          'transition-all duration-100'
        )}
      >
        ↓
      </span>
    </button>
  )
}
