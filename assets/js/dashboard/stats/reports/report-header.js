import React from 'react'

export function ReportHeader({ children }) {
  return (
    <div className="w-full flex justify-between border-b border-gray-200 dark:border-gray-750">
      {children}
    </div>
  )
}
