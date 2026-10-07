import React, { ReactNode } from 'react'
import {
  AppNavigationLink,
  AppNavigationTarget
} from '../navigation/use-app-navigate'
import { XMarkIcon } from '@heroicons/react/24/outline'
import classNames from 'classnames'

export type FilterPillAction = {
  type: 'link'
  navigationTarget: AppNavigationTarget
}

export type FilterPillProps = {
  plainText: string
  action?: FilterPillAction
  onRemoveClick?: () => void
  children: ReactNode
}

const PillContent = ({ children }: { children?: ReactNode }) => (
  <span className="inline-block max-w-2xs md:max-w-xs truncate">
    {children}
  </span>
)

const contentBaseClassName =
  'flex w-full h-full items-center rounded-l-md pl-2.5'

export function FilterPill({
  plainText,
  children,
  onRemoveClick,
  action
}: FilterPillProps) {
  const contentClassName = classNames(
    contentBaseClassName,
    !onRemoveClick && 'rounded-r-md pr-2.5'
  )

  return (
    <div className="flex h-8 rounded-md bg-white border border-gray-200 dark:border-gray-700 dark:bg-gray-800 text-gray-800 dark:text-gray-100 text-sm items-center">
      {action ? (
        <AppNavigationLink
          className={contentClassName}
          title={`Edit filter: ${plainText}`}
          {...action.navigationTarget}
        >
          <PillContent>{children}</PillContent>
        </AppNavigationLink>
      ) : (
        <div className={contentClassName} title={plainText}>
          <PillContent>{children}</PillContent>
        </div>
      )}
      {!!onRemoveClick && (
        <button
          title={`Remove filter: ${plainText}`}
          className="flex items-center h-full rounded-r-md pl-1.5 pr-2.5 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500 "
          onClick={onRemoveClick}
        >
          <XMarkIcon className="size-4" />
        </button>
      )}
    </div>
  )
}
