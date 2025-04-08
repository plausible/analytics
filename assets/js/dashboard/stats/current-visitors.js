import React, { useCallback, useEffect, useState } from 'react'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import * as api from '../api'
import { Tooltip } from '../util/tooltip'
import { SecondsSinceLastLoad } from '../util/seconds-since-last-load'
import { useQueryContext } from '../query-context'
import { useSiteContext } from '../site-context'
import { useLastLoadContext } from '../last-load-context'
import classNames from 'classnames'

export default function CurrentVisitors({
  className = '',
  tooltipBoundaryRef
}) {
  const { query } = useQueryContext()
  const lastLoadTimestamp = useLastLoadContext()
  const site = useSiteContext()
  const [currentVisitors, setCurrentVisitors] = useState(null)

  const updateCount = useCallback(() => {
    api
      .get(`/api/stats/${encodeURIComponent(site.domain)}/current-visitors`)
      .then((res) => setCurrentVisitors(res))
  }, [site.domain])

  useEffect(() => {
    document.addEventListener('tick', updateCount)

    return () => {
      document.removeEventListener('tick', updateCount)
    }
  }, [updateCount])

  useEffect(() => {
    updateCount()
  }, [query, updateCount])

  if (currentVisitors !== null && query.filters.length === 0) {
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
        boundary={tooltipBoundaryRef.current}
      >
        <AppNavigationLink
          search={(prev) => ({ ...prev, period: 'realtime' })}
          className={classNames(
            'h-9 flex items-center text-xs md:text-sm font-bold text-gray-500 dark:text-gray-300',
            className
          )}
        >
          <svg
            className="inline-block w-2 mr-1 text-green-500 fill-current"
            viewBox="0 0 16 16"
            xmlns="http://www.w3.org/2000/svg"
          >
            <circle cx="8" cy="8" r="8" />
          </svg>
          <div className="inline-block">
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
