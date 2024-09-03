/** @format */

import React, { ReactNode } from 'react'
import { getSortDirectionIndicator, SortDirection } from '../hooks/use-order-by'

export const SortButton = ({
  children,
  toggleSort,
  hint,
  sortDirection
}: {
  children: ReactNode
  toggleSort: () => void
  hint: string
  sortDirection: SortDirection | null
}) => {
  return (
    <button onClick={toggleSort} title={hint} className="hover:underline">
      {children}
      {sortDirection !== null && (
        <span> {getSortDirectionIndicator(sortDirection)}</span>
      )}
    </button>
  )
}
