import React from "react"
import { Link } from 'react-router-dom'
import * as url from '../../util/url'
import { BarsArrowUpIcon } from '@heroicons/react/20/solid'
import classNames from "classnames"

export default function WithImportedSwitch({query, info}) {
  if (info && info.visible) {
    const {togglable, tooltip_msg} = info
    const enabled = togglable && query.with_imported
    const target = url.setQuery('with_imported', (!enabled).toString())

    const linkClass = classNames({
      "dark:text-gray-300 text-gray-700": enabled,
      "dark:text-gray-500 text-gray-400": !enabled,
      "cursor-pointer": togglable,
      "pointer-events-none": !togglable,
    })
    
    return (
      <div tooltip={tooltip_msg} className="w-4 h-4 mx-2">
        <Link to={target} className={linkClass}>
          <BarsArrowUpIcon className="mt-0.5"/>
        </Link>
      </div>
    )
  } else {
    return null
  }
}