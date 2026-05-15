import React from 'react'
import classNames from 'classnames'

export function Toggle({ on, disabled }: { on: boolean; disabled?: boolean }) {
  return (
    <div
      className={classNames(
        'relative inline-flex h-4 w-7 shrink-0 rounded-full transition-colors duration-200',
        on && !disabled ? 'bg-indigo-600' : 'bg-gray-200 dark:bg-gray-600'
      )}
    >
      <span
        className={classNames(
          'inline-block mt-0.5 h-3 w-3 rounded-full bg-white shadow-sm transition-transform duration-200',
          on ? 'translate-x-[14px]' : 'translate-x-0.5'
        )}
      />
    </div>
  )
}
