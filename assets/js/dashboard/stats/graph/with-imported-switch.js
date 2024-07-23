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
  const {with_imported_switch, _imports_exist, _includes_imported} = info;
  const switchedOn = query.with_imported;
  
  // const { togglable, tooltip_msg } = info
  // const enabled = togglable && query.with_imported
  
  const iconClass = classNames("mt-0.5", {
    "dark:text-gray-300 text-gray-700": with_imported_switch.togglable,
    "dark:text-gray-500 text-gray-400": !with_imported_switch.togglable,
  })

    return (
      <div tooltip={with_imported_switch.tooltip_msg} className="w-4 h-4 mx-2">
        <LinkOrDiv isLink={with_imported_switch.togglable} search={(search) => ({...search, with_imported: !switchedOn})}>
          <BarsArrowUpIcon className={iconClass} />
        </LinkOrDiv>
      </div>
    )
}