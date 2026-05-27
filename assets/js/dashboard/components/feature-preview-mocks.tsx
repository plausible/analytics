import React from 'react'
import classNames from 'classnames'

/*
 * Non-interactive previews of the Funnels / Properties / Exploration reports,
 * rendered behind the CTA when the feature isn't available on the current
 * plan. They give users an at-a-glance idea of what the report looks like
 * without needing to navigate elsewhere. Always heavily blurred in their
 * parent container, so the goal is to be suggestive rather than pixel-perfect.
 */

export function PropertiesPreviewMock() {
  const rows = [98, 82, 68, 60, 45, 21, 12, 8, 5, 2]

  return (
    <div className="size-full flex flex-col gap-1.5 pt-9">
      {rows.map((width, i) => (
        <div
          key={i}
          className="h-7.5 bg-red-200/70 dark:bg-gray-500/30 rounded-sm"
          style={{ width: `${width}%` }}
        />
      ))}
    </div>
  )
}

export function FunnelsPreviewMock() {
  const steps = [{ visitors: 100 }, { visitors: 55 }, { visitors: 24 }]

  return (
    <div className="size-full flex flex-col pt-5">
      <div className="h-4 w-32 bg-gray-400/60 dark:bg-gray-600 rounded-md mb-8" />

      <div className="flex-1 flex items-end justify-between lg:justify-around gap-6">
        {steps.map((step, i) => (
          <div
            key={i}
            className="relative h-full flex-1 max-w-[160px] flex flex-col justify-end rounded-md overflow-hidden"
          >
            <div
              className="w-full bg-indigo-100 dark:bg-gray-700"
              style={{ height: `${100 - step.visitors}%` }}
            />
            <div
              className="w-full bg-indigo-500"
              style={{ height: `${step.visitors}%` }}
            />
          </div>
        ))}
      </div>

      <div className="flex justify-around gap-6 pt-4 pb-2">
        {steps.map((_, i) => (
          <div key={i} className="flex-1 max-w-[160px] flex justify-center">
            <div className="h-3 w-3/5 bg-gray-400/70 dark:bg-gray-600 rounded-md" />
          </div>
        ))}
      </div>
    </div>
  )
}

export function ExplorationPreviewMock() {
  const columns = [
    [98, 96, 54, 42, 27, 18, 15, 10, 5],
    [88, 70, 68, 30, 18, 16, 10, 9, 5],
    [82, 78, 48, 35, 25, 14, 12, 10, 5]
  ]

  return (
    <div className="size-full flex gap-3 pt-3">
      {columns.map((rows, colIdx) => (
        <div
          key={colIdx}
          className={classNames(
            'flex-1 flex-col rounded-lg border border-gray-400 dark:border-gray-500 overflow-hidden',
            colIdx === 2 ? 'hidden lg:flex' : 'flex'
          )}
        >
          <div className="h-12 shrink-0 flex items-center px-3">
            <div className="h-2.5 w-20 bg-gray-400/70 dark:bg-gray-500/80 rounded" />
          </div>
          <div className="flex flex-col gap-1.5 px-2 pb-2">
            {rows.map((width, i) => (
              <div
                key={i}
                className={
                  i === 0 && colIdx === 0
                    ? 'h-7.5 bg-indigo-300/80 dark:bg-indigo-500/70 rounded-sm'
                    : 'h-7.5 bg-indigo-200/70 dark:bg-indigo-500/30 rounded-sm'
                }
                style={{ width: `${width}%` }}
              />
            ))}
          </div>
        </div>
      ))}
    </div>
  )
}
