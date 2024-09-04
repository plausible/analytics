/** @format */

import React, { ReactNode } from 'react'
import { SortDirection } from '../hooks/use-order-by'
import classNames from 'classnames'

export const SortButton = ({
  children,
  toggleSort,
  hint,
  sortDirection,
  nextSortDirection
}: {
  children: ReactNode
  toggleSort: () => void
  hint: string
  sortDirection: SortDirection | null
  nextSortDirection: SortDirection
}) => {
  return (
    <button
      onClick={toggleSort}
      title={hint}
      className={classNames(
        'group',
        'hover:underline',
      )}
    >
      {children}
      <span
        className={classNames(
          'rounded inline-block h-4 w-4',
          'ml-1',
          {
            [SortDirection.asc]: 'rotate-180',
            [SortDirection.desc]: 'rotate-0'
          }[sortDirection ?? nextSortDirection],
          !sortDirection && 'opacity-0',
          !sortDirection && 'group-hover:opacity-100',
          sortDirection && 'group-hover:bg-gray-100 dark:group-hover:bg-gray-900',
          'transition',
        )}
      >
        ↓
      </span>
    </button>
  )
}
