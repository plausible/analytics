import React, { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom'
import * as api from '../api'
import * as url from '../util/url'
import { Tooltip } from '../util/tooltip';
import { SecondsSinceLastLoad } from '../util/seconds-since-last-load';

export default function CurrentVisitors(props) {
  const { site, query, lastLoadTimestamp, tooltipBoundary } = props
  const [currentVisitors, setCurrentVisitors] = useState(null)

  const updateCount = useCallback(() => {
    api.get(`/api/stats/${encodeURIComponent(site.domain)}/current-visitors`)
      .then((res) => setCurrentVisitors(res))
  }, [])

  useEffect(() => {
    document.addEventListener('tick', updateCount)

    return () => {
      document.removeEventListener('tick', updateCount)
    }
  }, [])

  useEffect(() => {
    updateCount()
  }, [query])

  function tooltipInfo() {
    return (
      <div>
        <p className="whitespace-nowrap text-small">Last updated <SecondsSinceLastLoad lastLoadTimestamp={lastLoadTimestamp} />s ago</p>
        <p className="whitespace-nowrap font-normal text-xs">Click to view realtime dashboard</p>
      </div>
    )
  }

  if (currentVisitors !== null && query.filters.length === 0) {
    return (
      <Tooltip info={tooltipInfo()} boundary={tooltipBoundary}>
        <Link to={url.setQuery('period', 'realtime')} className="block ml-1 md:ml-2 mr-auto text-xs md:text-sm font-bold text-gray-500 dark:text-gray-300">
          <svg className="inline w-2 mr-1 md:mr-2 text-green-500 fill-current" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
            <circle cx="8" cy="8" r="8" />
          </svg>
          {currentVisitors} <span className="hidden sm:inline-block">current visitor{currentVisitors === 1 ? '' : 's'}</span>
        </Link>
      </Tooltip>
    )
  } else {
    return null
  }
}
