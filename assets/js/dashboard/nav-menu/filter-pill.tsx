/** @format */

import React, { ReactNode } from 'react'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import { filterRoute } from '../router'
import { XMarkIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'

export function FilterPill({
  className,
  plainText,
  children,
  modalToOpen,
  onRemoveClick
}: {
  className?: string
  plainText: string
  modalToOpen: string
  children: ReactNode
  onRemoveClick: () => void
}) {
  return (
    <div
      className={classNames(
        'flex h-9 shadow rounded bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 text-sm items-center',
        className
      )}
    >
      <AppNavigationLink
        title={`Edit filter: ${plainText}`}
        className="flex w-full h-full items-center py-2 pl-3"
        path={filterRoute.path}
        params={{ field: modalToOpen }}
        search={(search) => search}
      >
        <span className="inline-block max-w-2xs md:max-w-xs truncate">
          {children}
        </span>
      </AppNavigationLink>
      <button
        title={`Remove filter: ${plainText}`}
        className="flex items-center h-full px-2 mr-1 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500 "
        onClick={() => onRemoveClick()}
      >
        <XMarkIcon className="w-4 h-4" />
      </button>
    </div>
  )
}
