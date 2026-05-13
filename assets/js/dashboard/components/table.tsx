import classNames from 'classnames'
import React, { useState } from 'react'
import { ColumnConfiguration } from '../stats/breakdowns'

function Row<T>({
  row,
  columns,
  rowKey,
  tappedKey,
  onTap
}: {
  row: T
  columns: ColumnConfiguration<T>[]
  rowKey: string
  tappedKey: string | null
  onTap: (key: string | null) => void
}) {
  const [isHovered, setIsHovered] = useState(false)
  const isTapped = tappedKey === rowKey
  const isActive = isHovered || isTapped

  const handleClick = (e: React.MouseEvent) => {
    if (window.innerWidth < 768 && !(e.target as HTMLElement).closest('a')) {
      onTap(isTapped ? null : rowKey)
    }
  }

  return (
    <tr
      data-testid="report-row"
      className="group text-sm dark:text-gray-200 md:cursor-default cursor-pointer"
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      onClick={handleClick}
    >
      {columns.map((col) => (
        <td
          key={`${col.key}_${rowKey}`}
          className={classNames(
            'p-2 font-medium first:rounded-s-sm last:rounded-e-sm',
            col.width
          )}
          align={col.align}
        >
          {col.renderCell(row, isActive)}
        </td>
      ))}
    </tr>
  )
}

export function Table<T>({
  data,
  columns,
  getRowKey
}: {
  data: { pages: T[][] }
  columns: ColumnConfiguration<T>[]
  getRowKey: (row: T) => string
}) {
  const [tappedKey, setTappedKey] = useState<string | null>(null)

  return (
    <table className="border-collapse table-striped table-fixed w-max min-w-full">
      <thead className="sticky top-0 bg-white dark:bg-gray-900 z-10">
        <tr className="text-xs font-semibold text-gray-500 dark:text-gray-400">
          {columns.map((col) => (
            <th
              key={`header_${col.key}`}
              data-testid="report-header"
              className={classNames('p-2', col.width)}
              align={col.align}
            >
              {col.renderLabel()}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {data.pages.map((page, pageIndex) =>
          page.map((row) => {
            const rowKey = `${getRowKey(row)}_${pageIndex}`
            return (
              <Row
                key={rowKey}
                row={row}
                columns={columns}
                rowKey={rowKey}
                tappedKey={tappedKey}
                onTap={setTappedKey}
              />
            )
          })
        )}
      </tbody>
    </table>
  )
}
