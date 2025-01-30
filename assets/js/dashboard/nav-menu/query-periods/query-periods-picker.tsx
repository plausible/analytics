/** @format */

import React from 'react'
import classNames from 'classnames'
import { useQueryContext } from '../../query-context'
import { isComparisonEnabled } from '../../query-time-periods'
import { MovePeriodArrows } from './move-period-arrows'
import { MemoisedQueryPeriodMenu } from './query-period-menu'
import {
  ComparisonPeriodMenuButton,
  ComparisonPeriodMenuItems
} from './comparison-period-menu'
import { Menu, Popover } from '@headlessui/react'

export function QueryPeriodsPicker({ className }: { className?: string }) {
  const { query } = useQueryContext()
  const isComparing = isComparisonEnabled(query.comparison)

  return (
    <div className={classNames('flex shrink-0', className)}>
      <MovePeriodArrows className={isComparing ? 'hidden md:flex' : ''} />
      <Menu as="div" className="min-w-36 md:relative lg:w-48">
        {({ close }) => <MemoisedQueryPeriodMenu closeDropdown={close} />}
      </Menu>
      {isComparing && (
        <>
          <div className="my-auto px-1 text-sm font-medium text-gray-800 dark:text-gray-200">
            <span className="hidden md:inline px-1">vs.</span>
          </div>
          <Popover as="div" className="min-w-36 md:relative lg:w-48">
            {({ close }) => (
              <>
                <ComparisonPeriodMenuButton />
                <ComparisonPeriodMenuItems closeDropdown={close} />
              </>
            )}
          </Popover>
        </>
      )}
    </div>
  )
}
