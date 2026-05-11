import React from 'react'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import { Tooltip } from '../util/tooltip'
import { SecondsSinceLastLoad } from '../util/seconds-since-last-load'
import { useLastLoadContext } from '../last-load-context'
import { useCurrentVisitorsContext } from '../current-visitors-context'
import classNames from 'classnames'
import { popover } from '../components/popover'

export default function CurrentVisitors({ className = '' }) {
  const lastLoadTimestamp = useLastLoadContext()
  const currentVisitors = useCurrentVisitorsContext()

  if (currentVisitors !== null) {
    return (
      <Tooltip
        info={
          <div>
            <p className="whitespace-nowrap text-small">
              Last updated{' '}
              <SecondsSinceLastLoad lastLoadTimestamp={lastLoadTimestamp} />s
              ago
            </p>
            <p className="whitespace-nowrap font-normal text-xs">
              Click to view realtime dashboard
            </p>
          </div>
        }
      >
        <AppNavigationLink
          search={(prev) => ({ ...prev, period: 'realtime' })}
          className={classNames(
            popover.toggleButton.classNames.rounded,
            popover.toggleButton.classNames.ghost,
            'px-2',
            className
          )}
        >
          <svg
            className="inline-block w-2 text-green-500 fill-current"
            viewBox="0 0 16 16"
            xmlns="http://www.w3.org/2000/svg"
          >
            <circle cx="8" cy="8" r="8" />
          </svg>
          <div className="inline-block text-gray-500 dark:text-gray-400">
            {currentVisitors}
            <span className="hidden lg:inline">
              {' '}
              current visitor{currentVisitors === 1 ? '' : 's'}
            </span>
          </div>
        </AppNavigationLink>
      </Tooltip>
    )
  } else {
    return null
  }
}
