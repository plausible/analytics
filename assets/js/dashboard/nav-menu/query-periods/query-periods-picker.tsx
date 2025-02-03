/** @format */

import React from 'react'
import classNames from 'classnames'
import { useQueryContext } from '../../query-context'
import { isComparisonEnabled } from '../../query-time-periods'
import { MovePeriodArrows } from './move-period-arrows'
import { QueryPeriodMenu } from './query-period-menu'
import {
  ComparisonPeriodMenuButton,
  ComparisonPeriodMenuItems
} from './comparison-period-menu'
import { Popover } from '@headlessui/react'

export function QueryPeriodsPicker({ className }: { className?: string }) {
  const { query } = useQueryContext()
  const isComparing = isComparisonEnabled(query.comparison)

  return (
    <div className={classNames('flex shrink-0', className)}>
      <MovePeriodArrows className={isComparing ? 'hidden md:flex' : ''} />
      <Popover className="min-w-36 md:relative lg:w-48">
        {({ close, open }) => (
          <QueryPeriodMenu dropdownIsOpen={open} closeDropdown={close} />
        )}
      </Popover>
      {isComparing && (
        <>
          <div className="my-auto px-1 text-sm font-medium text-gray-800 dark:text-gray-200">
            <span className="hidden md:inline px-1">vs.</span>
          </div>
          <Popover className="min-w-36 md:relative lg:w-48">
            {({ close, open }) => (
              <>
                <ComparisonPeriodMenuButton />
                <ComparisonPeriodMenuItems
                  dropdownIsOpen={open}
                  closeDropdown={close}
                />
              </>
            )}
          </Popover>
        </>
      )}
    </div>
  )
}
