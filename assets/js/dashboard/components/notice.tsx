import React from 'react'
import classNames from 'classnames'

export type NoticeProps = {
  title: string
  description?: string
  className?: string
}

export const Notice = ({ title, description, className }: NoticeProps) => (
  <div
    className={classNames(
      'flex flex-col gap-y-0.5 rounded-md bg-yellow-100/60 dark:bg-yellow-700/30 px-3 py-2.5',
      className
    )}
  >
    <p className="text-sm font-semibold text-gray-900 dark:text-gray-100">
      {title}
    </p>
    {description && (
      <p className="text-sm text-gray-600 dark:text-gray-200/60">
        {description}
      </p>
    )}
  </div>
)
