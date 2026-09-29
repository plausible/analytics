import React, { useEffect, useRef } from 'react'
import classNames from 'classnames'
import { Filter, FilterOperator } from '../dashboard-state'
import {
  FILTER_OPERATIONS_DISPLAY_NAMES,
  getSupportedOperations
} from '../util/filters'
import { popover, SelectedCheckmark } from '../components/popover'

export const FilterOperatorList = ({
  filter,
  onSelect
}: {
  filter: Filter
  onSelect: (operation: FilterOperator) => void
}) => {
  const [selectedOperation, filterKey] = filter
  const listRef = useRef<HTMLDivElement>(null)
  const operations: FilterOperator[] = getSupportedOperations(filterKey)

  useEffect(() => {
    listRef.current
      ?.querySelector<HTMLButtonElement>('[data-selected="true"]')
      ?.focus({ preventScroll: true })
  }, [])

  const onKeyDown = (event: React.KeyboardEvent) => {
    if (!['ArrowDown', 'ArrowUp'].includes(event.key)) {
      return
    }
    event.preventDefault()
    const buttons = Array.from(
      listRef.current?.querySelectorAll('button') ?? []
    )
    const index = buttons.findIndex((b) => b === document.activeElement)
    const step = event.key === 'ArrowDown' ? 1 : -1
    buttons[(index + step + buttons.length) % buttons.length]?.focus()
  }

  return (
    <div
      ref={listRef}
      role="group"
      aria-label="Operators"
      className="flex flex-col gap-y-0.5"
    >
      {operations.map((operation) => (
        <button
          key={operation}
          type="button"
          data-selected={operation === selectedOperation}
          className={classNames(
            'w-full text-left',
            popover.items.classNames.navigationLink,
            popover.items.classNames.selectedOption,
            popover.items.classNames.hoverLink
          )}
          onClick={() => onSelect(operation)}
          onKeyDown={onKeyDown}
        >
          {FILTER_OPERATIONS_DISPLAY_NAMES[operation]}
          <SelectedCheckmark selected={operation === selectedOperation} />
        </button>
      ))}
    </div>
  )
}
