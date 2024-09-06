/** @format */

import classNames from 'classnames'
import React, { ReactNode } from 'react'
import { SortDirection } from '../hooks/use-order-by'
import { SortButton } from './sort-button'

export type ColumnConfiguraton<T extends Record<string, unknown>> = {
  /** Unique ID */
  key: string
  /** Column title */
  label: ReactNode
  /** Where to find the value for any particular item for this column. @example "name" */
  accessor: keyof T
  /** If defined, the column is considered sortable. @see SortButton */
  onSort?: () => void
  sortDirection?: SortDirection
  /** CSS class string. @example "w-24 md:w-32" */
  width: string
  /** Aligns column content. */
  align?: 'left' | 'right'
  /**
   * Function used to transform the value found at item[accessor] for the cell. Superseded by renderItem if present. @example 1120 => "1.1k"
   */
  renderValue?: (value: unknown) => ReactNode
  /** Function used to create richer cells */
  renderItem?: (item: T) => ReactNode
}

export const TableHeaderCell = ({
  children,
  className,
  align
}: {
  children: ReactNode
  className: string
  align?: 'left' | 'right'
}) => {
  return (
    <th
      className={classNames(
        'p-2 text-xs font-bold text-gray-500 dark:text-gray-400 tracking-wide',
        className
      )}
      align={align}
    >
      {children}
    </th>
  )
}

export const TableCell = ({
  children,
  className,
  align
}: {
  children: ReactNode
  className: string
  align?: 'left' | 'right'
}) => {
  return (
    <td className={classNames('p-2 font-medium', className)} align={align}>
      {children}
    </td>
  )
}

export const ItemRow = <T extends Record<string, string | number | ReactNode>>({
  item,
  columns
}: {
  item: T
  columns: ColumnConfiguraton<T>[]
}) => {
  return (
    <tr className="text-sm dark:text-gray-200">
      {columns.map(
        ({ accessor, width, align, renderValue, renderItem }, colIndex) => (
          <TableCell key={colIndex} className={width} align={align}>
            {renderItem
              ? renderItem(item)
              : renderValue
                ? renderValue(item[accessor])
                : (item[accessor] ?? '')}
          </TableCell>
        )
      )}
    </tr>
  )
}

export const Table = <T extends Record<string, string | number | ReactNode>>({
  data,
  columns
}: {
  columns: ColumnConfiguraton<T>[]
  data: T[] | { pages: T[][] }
}) => {
  return (
    <table className="w-max overflow-x-auto md:w-full table-striped table-fixed">
      <thead>
        <tr className="text-xs font-bold text-gray-500 dark:text-gray-400">
          {columns.map((column) => (
            <TableHeaderCell
              key={column.key}
              className={classNames('p-2 tracking-wide', column.width)}
              align={column.align}
            >
              {column.onSort ? (
                <SortButton
                  toggleSort={column.onSort}
                  sortDirection={column.sortDirection ?? null}
                >
                  {column.label}
                </SortButton>
              ) : (
                column.label
              )}
            </TableHeaderCell>
          ))}
        </tr>
      </thead>
      <tbody>
        {Array.isArray(data)
          ? data.map((item, itemIndex) => (
              <ItemRow item={item} columns={columns} key={itemIndex} />
            ))
          : data.pages.map((page, pageIndex) =>
              page.map((item, itemIndex) => (
                <ItemRow
                  item={item}
                  columns={columns}
                  key={`${pageIndex}${itemIndex}`}
                />
              ))
            )}
      </tbody>
    </table>
  )
}
