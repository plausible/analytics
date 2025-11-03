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
    const link = (
      <AppNavigationLink
        search={(prev) => {
          if (prev.period === 'realtime') {
            const { period, ...rest } = prev
            return rest
          } else {
            return { ...prev, period: 'realtime' }
          }
        }}
        className={classNames(
          'py-2.5 px-3 flex items-center rounded-md text-xs md:text-sm font-medium',
          'text-gray-500 dark:text-gray-300 hover:bg-gray-150 hover:text-gray-800 dark:hover:bg-gray-800 dark:hover:text-gray-100 active:bg-gray-100 dark:active:bg-gray-700 transition-all duration-150',
          className
        )}
      >
        <span className="relative flex size-2 mr-2.5">
          <span className={classNames("absolute inline-flex h-full w-full scale-120 rounded-full bg-green-500", query.period === 'realtime' && 'animate-ping')}></span>
          <span className="relative inline-flex size-2 rounded-full bg-green-500"></span>
        </span>
        <div className="inline-block">
          {currentVisitors}
          <span className="hidden lg:inline">
            {' '}
            current visitor{currentVisitors === 1 ? '' : 's'}
          </span>
        </div>
        {query.period === 'realtime' && (
          <span className="ml-1.5 inline-flex items-center text-xs md:text-sm text-gray-400 dark:text-gray-400">
            •{' '}
            <SecondsSinceLastLoad lastLoadTimestamp={lastLoadTimestamp} />
            s ago
          </span>
        )}
      </AppNavigationLink>
    )

    return query.period !== 'realtime' ? (
      <Tooltip
        info={"Click to view realtime dashboard"}
        boundary={tooltipBoundaryRef.current}
        disableOverflow
        delayed
      >
        {link}
      </Tooltip>
    ) : (
      link
    )
  } else {
    return null
  }
}
