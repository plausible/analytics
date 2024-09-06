/** @format */

import classNames from 'classnames'
import React, { ReactNode } from 'react'
import { SortDirection } from '../hooks/use-order-by'
import { SortButton } from './sort-button'

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

export type ColumnConfiguraton<T> = {
  key: string
  accessor: keyof T
  onSort?: () => void
  sortDirection?: SortDirection
  width: string
  label: ReactNode
  align?: 'left' | 'right'
  renderValue?: (value: unknown) => ReactNode
  renderItem?: (item: T) => ReactNode
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
                : item[accessor]}
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
