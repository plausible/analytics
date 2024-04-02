import React from "react"
import { parseNaiveDate, isBefore } from '../../util/date'
import { Link } from 'react-router-dom'
import * as url from '../../util/url'
import { BarsArrowUpIcon } from '@heroicons/react/20/solid'

export default function WithImportedSwitch({site, topStatData}) {
  if (!topStatData?.imports_exist) {
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
    const withImported = topStatData.with_imported;
    const toggleColor = withImported ? " dark:text-gray-300 text-gray-700" : " dark:text-gray-500 text-gray-400"
    const target = url.setQuery('with_imported', !withImported)
    const tip = withImported ? "" : "do not ";

    return (
      <Link to={target} className="w-4 h-4 mx-2">
        <div tooltip={`Stats ${tip}include imported data.`} className="cursor-pointer w-4 h-4">
          <BarsArrowUpIcon className={"absolute " + toggleColor} />
        </div>
      </Link>
    )
  } else {
    return null
  }
}