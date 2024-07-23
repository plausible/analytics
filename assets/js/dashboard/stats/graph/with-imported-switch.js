import React from "react"
import { BarsArrowUpIcon } from '@heroicons/react/20/solid'
import classNames from "classnames"
import { useQueryContext } from "../../query-context"
import { Link } from "@tanstack/react-router"

function LinkOrDiv({ isLink, to, search, children }) {
  if (isLink) {
    return <Link to={to} search={search}>{children}</Link>
  } else {
    return <div>{children}</div>
  }
}

export default function WithImportedSwitch({ info }) {
  const { query } = useQueryContext();

  if (!info?.visible) {
    return null;
  }
  
  const { togglable, tooltip_msg } = info
  const enabled = togglable && query.with_imported
  
  const iconClass = classNames("mt-0.5", {
    "dark:text-gray-300 text-gray-700": enabled,
    "dark:text-gray-500 text-gray-400": !enabled,
  })

    return (
      <div tooltip={tooltip_msg} className="w-4 h-4 mx-2">
        <LinkOrDiv isLink={togglable} search={(search) => ({...search, with_imported: !enabled})}>
          <BarsArrowUpIcon className={iconClass} />
        </LinkOrDiv>
      </div>
    )
}