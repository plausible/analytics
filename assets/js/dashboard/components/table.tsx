/** @format */

import classNames from 'classnames'
import React, { ReactNode } from 'react'

export const TableHeaderCell = ({
  children,
  className
}: {
  children: ReactNode
  className: string
}) => {
  return (
    <th
      className={classNames(
        'px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider',
        className
      )}
    >
      {children}
    </th>
  )
}

export const TableCell = ({
  children,
  className
}: {
  children: ReactNode
  className: string
}) => {
  return (
    <td
      className={classNames(
        'px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900',
        className
      )}
    >
      {children}
    </td>
  )
}

export const Table = <T extends Record<string, string | number | ReactNode>>({
  data,
  columns
}: {
  columns: { accessor: keyof T; width: string; label: string }[]
  data: T[]
}) => {
  return (
    <div className="overflow-x-auto">
      <table className="min-w-full bg-white border border-gray-200">
        <thead className="bg-gray-50">
          <tr>
            {columns.map((column, index) => (
              <TableHeaderCell key={index} className={column.width}>
                {column.label}
              </TableHeaderCell>
            ))}
          </tr>
        </thead>
        <tbody className="bg-white divide-y divide-gray-200">
          {data.map((item, itemIndex) => (
            <tr key={itemIndex}>
              {columns.map(({ accessor, width }, colIndex) => (
                <TableCell key={colIndex} className={width}>
                  {item[accessor]}
                </TableCell>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
