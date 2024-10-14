/** @format */

import React, { ReactNode } from 'react'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import { filterRoute } from '../router'
import { XMarkIcon } from '@heroicons/react/20/solid'

export function FilterPill({
  plainText,
  children,
  modalToOpen,
  onRemoveClick
}: {
  plainText: string
  modalToOpen: string
  children: ReactNode
  onRemoveClick: () => void
}) {
  return (
    <div className="flex bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 shadow text-sm rounded mr-2 items-center">
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
        className="flex h-full w-full px-2 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500 items-center"
        onClick={() => onRemoveClick()}
      >
        <XMarkIcon className="w-4 h-4" />
      </button>
    </div>
  )
}
