import React from 'react'
import classNames from 'classnames'

export function ReportLayout({ children, testId = undefined, className = undefined }) {
  return (
    <div
      data-testid={testId}
      className={classNames(
        'relative min-h-[430px] w-full p-5 flex flex-col bg-white dark:bg-gray-900 shadow-sm rounded-md md:min-h-initial md:h-27.25rem',
        className
      )}
    >
      {children}
    </div>
  )
}
