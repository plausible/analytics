import React, { ReactNode } from 'react'
import {
  AppNavigationLink,
  AppNavigationTarget
} from '../navigation/use-app-navigate'
import { XMarkIcon } from '@heroicons/react/24/outline'
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
  const contentClassName = 'flex items-center'

  return (
    <div
      className={classNames(
        'flex items-center gap-x-1 py-2 px-3 rounded-md bg-white border border-gray-200 text-gray-700 dark:text-gray-300 text-xs uppercase font-medium tracking-tight',
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
              className="flex items-center mt-px cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500 "
              onClick={interactive.onRemoveClick}
            >
              <XMarkIcon className="size-3.5 stroke-2" />
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
