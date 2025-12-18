import React, { useRef, useEffect } from 'react'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import { Tooltip } from '../util/tooltip'

function detailsIcon() {
  return (
    <svg
      className="feather"
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3" />
    </svg>
  )
}

export default function MoreLink({
  linkProps,
  list,
  className,
  onClick,
  loading
}) {
  const portalRef = useRef(null)

  useEffect(() => {
    if (typeof document !== 'undefined') {
      portalRef.current = document.body
    }
  }, [])

  if (!list || list.length === 0 || !linkProps || loading) {
    return null
  }

  return (
    <Tooltip info="View details" containerRef={portalRef}>
      <AppNavigationLink
        {...linkProps}
        className="flex mt-px text-gray-500 dark:text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors duration-150"
        onClick={onClick}
      >
        {detailsIcon()}
      </AppNavigationLink>
    </Tooltip>
  )
}
