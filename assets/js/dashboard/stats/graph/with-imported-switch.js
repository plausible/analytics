import React from "react"
import { parseNaiveDate, isBefore } from '../../util/date'
import { Link } from 'react-router-dom'
import * as url from '../../util/url'

export default function WithImportedSwitch({site, topStatData}) {
  if (!topStatData?.imported_source) {
    return null
  }

  function isBeforeNativeStats(date) {
    if (!date) return false

    const nativeStatsBegin = parseNaiveDate(site.nativeStatsBegin)
    const parsedDate = parseNaiveDate(date)

    return isBefore(parsedDate, nativeStatsBegin, "day")
  }

  const isQueryingImportedPeriod = isBeforeNativeStats(topStatData.from)
  const isComparingImportedPeriod = isBeforeNativeStats(topStatData.comparing_from)

  if (isQueryingImportedPeriod || isComparingImportedPeriod) {
    const source = topStatData.imported_source
    const withImported = topStatData.with_imported;
    const strike = withImported ? "" : " line-through"
    const target = url.setQuery('with_imported', !withImported)
    const tip = withImported ? "" : "do not ";

    return (
      <Link to={target} className="w-4 h-4 mx-2">
        <div tooltip={`Stats ${tip}include data imported from ${source}.`} className="cursor-pointer w-4 h-4">
          <svg className="absolute dark:text-gray-300 text-gray-700" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <text x="4" y="18" fontSize="24" fill="currentColor" className={"text-gray-700 dark:text-gray-300" + strike}>{source[0].toUpperCase()}</text>
          </svg>
        </div>
      </Link>
    )
  } else {
    return null
  }
}