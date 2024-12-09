/** @format */

import React, { ReactNode } from 'react'
import {
  AppNavigationLink,
  AppNavigationTarget
} from '../navigation/use-app-navigate'
import { XMarkIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'

export type FilterPillProps = {
  className?: string
  plainText: string
  interactive:
    | {
        onRemoveClick?: () => void
        navigationTarget: AppNavigationTarget
      }
    | false
  children: ReactNode
  actions?: ReactNode
}

export function FilterPill({
  className,
  plainText,
  children,
  interactive,
  actions
}: FilterPillProps) {
  const c = 'flex w-full h-full items-center py-2 pl-3 last:pr-3'
  const inner = (
    <span className="inline-block max-w-2xs md:max-w-xs truncate">
      {children}
    </span>
  )

  return (
    <div className={className}>
      <div
        className={classNames(
          'm-1 flex h-9 shadow rounded bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 text-sm items-center',
          className
        )}
      >
        {interactive ? (
          <>
            <AppNavigationLink
              className={c}
              title={`Edit filter: ${plainText}`}
              {...interactive.navigationTarget}
            >
              {inner}
            </AppNavigationLink>
            {!!interactive.onRemoveClick && (
              <button
                title={`Remove filter: ${plainText}`}
                className="flex items-center h-full px-2 mr-1 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500 "
                onClick={interactive.onRemoveClick}
              >
                <XMarkIcon className="w-4 h-4" />
              </button>
            )}
            {actions}
          </>
        ) : (
          <>
            <div className={c} title={plainText}>
              {inner}
            </div>
            {actions}
          </>
        )}
      </div>
    </div>
  )
}
