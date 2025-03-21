/** @format */

import classNames from 'classnames'
import React, { ReactNode } from 'react'
import { SortDirection } from '../hooks/use-order-by'
import { SortButton } from './sort-button'
import { Tooltip } from '../util/tooltip'

export type ColumnConfiguraton<T extends Record<string, unknown>> = {
  /** Unique column ID, used for sorting purposes and to get the value of the cell using rowItem[key] */
  key: keyof T
  /** Column title */
  label: string
  /** If defined, the column is considered sortable. @see SortButton */
  onSort?: () => void
  sortDirection?: SortDirection
  /** CSS class string. @example "w-24 md:w-32" */
  width: string
  /** Aligns column content. */
  align?: 'left' | 'right'
  /** A warning to be rendered as a tooltip for the column header */
  metricWarning?: string
  /**
   * Function used to transform the value found at item[key] for the cell. Superseded by renderItem if present. @example 1120 => "1.1k"
   */
  renderValue?: (item: T) => ReactNode
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
  rowIndex,
  pageIndex,
  item,
  columns
}: {
  rowIndex: number
  pageIndex?: number
  item: T
  columns: ColumnConfiguraton<T>[]
}) => {
  return (
    <tr className="text-sm dark:text-gray-200">
      {columns.map(({ key, width, align, renderValue, renderItem }) => (
        <TableCell
          key={`${(pageIndex ?? null) === null ? '' : `page_${pageIndex}_`}row_${rowIndex}_${String(key)}`}
          className={width}
          align={align}
        >
          {renderItem
            ? renderItem(item)
            : renderValue
              ? renderValue(item)
              : (item[key] ?? '')}
        </TableCell>
      ))}
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
  const renderColumnLabel = (column: ColumnConfiguraton<T>) => {
    if (column.metricWarning) {
      return (
        <Tooltip
          info={warningSpan(column.metricWarning)}
          className="inline-block"
        >
          {column.label + ' *'}
        </Tooltip>
      )
    } else {
      return column.label
    }
  }

  const warningSpan = (warning: string) => {
    return (
      <span className="text-xs font-normal whitespace-nowrap">
        {'* ' + warning}
      </span>
    )
  }

  return (
    <table className="w-max overflow-x-auto md:w-full table-striped table-fixed">
      <thead>
        <tr className="text-xs font-bold text-gray-500 dark:text-gray-400">
          {columns.map((column) => (
            <TableHeaderCell
              key={`header_${String(column.key)}`}
              className={classNames('p-2 tracking-wide', column.width)}
              align={column.align}
            >
              {column.onSort ? (
                <SortButton
                  toggleSort={column.onSort}
                  sortDirection={column.sortDirection ?? null}
                >
                  {renderColumnLabel(column)}
                </SortButton>
              ) : (
                renderColumnLabel(column)
              )}
            </TableHeaderCell>
          ))}
        </tr>
      </thead>
      <tbody>
        {Array.isArray(data)
          ? data.map((item, rowIndex) => (
              <ItemRow
                item={item}
                columns={columns}
                rowIndex={rowIndex}
                key={rowIndex}
              />
            ))
          : data.pages.map((page, pageIndex) =>
              page.map((item, rowIndex) => (
                <ItemRow
                  item={item}
                  columns={columns}
                  rowIndex={rowIndex}
                  pageIndex={pageIndex}
                  key={`page_${pageIndex}_row_${rowIndex}`}
                />
              ))
            )}
      </tbody>
    </table>
  )
}
