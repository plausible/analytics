/** @format */

import React from 'react'
import classNames from 'classnames'
import {
  ArrowPathIcon,
  ExclamationTriangleIcon,
  XMarkIcon
} from '@heroicons/react/24/outline'

export const ErrorPanel = ({
  errorMessage,
  className,
  onClose,
  onRetry
}: {
  errorMessage: string
  className?: string
  onClose?: () => void
  onRetry?: () => void
}) => (
  <div
    className={classNames(
      'flex gap-x-1 rounded bg-red-100 text-red-600 dark:bg-red-200 dark:text-red-800 p-4',
      className
    )}
  >
    <div className="mt-1 flex">
      <ExclamationTriangleIcon className="block w-4 h-4 shrink-0" />
    </div>
    <div className="break-all text-sm/5">{errorMessage}</div>
    {typeof onClose === 'function' && (
      <button
        className="flex ml-auto w-5 h-5 items-center justify-center hover:text-red-700 dark:hover:text-red-900"
        onClick={onClose}
        title="Close notice"
      >
        <XMarkIcon className="block w-4 h-4 shrink-0" />
      </button>
    )}
    {typeof onRetry === 'function' && (
      <button
        className="flex ml-auto w-5 h-5 items-center justify-center hover:text-red-700 dark:hover:text-red-900"
        onClick={onRetry}
        title="Retry"
      >
        <ArrowPathIcon className="block w-4 h-4 shrink-0" />
      </button>
    )}
  </div>
)
