import React from 'react'
import classNames from 'classnames'

export type SegmentedControlOption<T extends string> = {
  value: T
  label: string
}

export function SegmentedControl<T extends string>({
  options,
  selected,
  onSelect,
  ariaLabel,
  getTestId
}: {
  options: SegmentedControlOption<T>[]
  selected: T
  onSelect: (value: T) => void
  ariaLabel: string
  getTestId?: (value: T, isSelected: boolean) => string | undefined
}) {
  return (
    <div
      role="group"
      aria-label={ariaLabel}
      className="inline-flex items-stretch rounded-lg border border-gray-300 p-0.5 dark:border-gray-600"
    >
      {options.map(({ value, label }) => {
        const isSelected = value === selected
        return (
          <button
            key={value}
            type="button"
            title={label}
            aria-pressed={isSelected}
            aria-label={label}
            onClick={() => onSelect(value)}
            data-testid={getTestId?.(value, isSelected)}
            data-selected={isSelected}
            className={classNames(
              'flex-1 whitespace-nowrap rounded-md py-1 px-1.5 text-xs font-medium transition-colors',
              isSelected
                ? 'bg-gray-150 text-gray-900 dark:bg-gray-600/80 dark:text-gray-100'
                : 'text-gray-500 dark:text-gray-300'
            )}
          >
            {label}
          </button>
        )
      })}
    </div>
  )
}
