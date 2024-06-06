import React from "react"
import { Link } from 'react-router-dom'
import * as url from '../../util/url'
import { BarsArrowUpIcon } from '@heroicons/react/20/solid'
import classNames from "classnames"

function LinkOrDiv({isLink, target, children}) {
  if (isLink) {
    return <Link to={target}>{ children }</Link>
  } else {
    return <div>{ children }</div>
  }
}

export default function WithImportedSwitch({query, info}) {
  if (info && info.visible) {
    const {togglable, tooltip_msg} = info
    const enabled = togglable && query.with_imported
    const target = url.setQuery('with_imported', (!enabled).toString())

    const iconClass = classNames("mt-0.5", {
      "dark:text-gray-300 text-gray-700": enabled,
      "dark:text-gray-500 text-gray-400": !enabled,
    })
    
    return (
      <div tooltip={tooltip_msg} className="w-4 h-4 mx-2">
        <LinkOrDiv isLink={togglable} target={target}>
          <BarsArrowUpIcon className={iconClass}/>
        </LinkOrDiv>
      </div>
    )
  } else {
    return null
  }
}