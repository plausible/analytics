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

const PillContent = ({ children }: { children?: ReactNode }) => (
  <span className="inline-block max-w-2xs md:max-w-xs truncate">
    {children}
  </span>
)

export function FilterPill({
  className,
  plainText,
  children,
  interactive,
  actions
}: FilterPillProps) {
  const contentClassName = 'flex w-full h-full items-center pl-2.5 last:pr-2.5'

  return (
    <div
      className={classNames(
        'flex h-8 shadow rounded-md bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 text-sm items-center',
        className
      )}
    >
      {interactive ? (
        <>
          <AppNavigationLink
            className={contentClassName}
            title={`Edit filter: ${plainText}`}
            {...interactive.navigationTarget}
          >
            <PillContent>{children}</PillContent>
          </AppNavigationLink>
          {!!interactive.onRemoveClick && (
            <button
              title={`Remove filter: ${plainText}`}
              className="flex items-center h-full pl-1.5 pr-2.5 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500 "
              onClick={interactive.onRemoveClick}
            >
              <XMarkIcon className="w-4 h-4" />
            </button>
          )}
          {actions}
        </>
      ) : (
        <>
          <div className={contentClassName} title={plainText}>
            <PillContent>{children}</PillContent>
          </div>
          {actions}
        </>
      )}
    </div>
  )
}
