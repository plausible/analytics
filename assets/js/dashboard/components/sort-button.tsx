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
      className={classNames('group', 'hover:underline', 'relative')}
    >
      {children}
      <span
        title={next.hint}
        className={classNames(
          'absolute',
          'rounded inline-block h-4 w-4',
          'ml-1',
          {
            [SortDirection.asc]: 'rotate-180',
            [SortDirection.desc]: 'rotate-0'
          }[sortDirection ?? next.direction],
          !sortDirection && 'opacity-0',
          !sortDirection && 'group-hover:opacity-100',
          sortDirection &&
            'group-hover:bg-gray-100 dark:group-hover:bg-gray-900',
          'transition'
        )}
      >
        ↓
      </span>
    </button>
  )
}
