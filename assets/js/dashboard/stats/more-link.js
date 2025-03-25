import React from 'react'
import { AppNavigationLink } from '../navigation/use-app-navigate'

function detailsIcon() {
  return (
    <svg
      className="feather mr-1"
      style={{ marginTop: '-2px' }}
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

export default function MoreLink({ linkProps, list, className, onClick }) {
  if (list.length > 0) {
    return (
      <div className={`w-full text-center ${className ? className : ''}`}>
        <AppNavigationLink
          {...linkProps}
          className="leading-snug font-bold text-sm text-gray-500 dark:text-gray-400 hover:text-red-500 dark:hover:text-red-400 transition tracking-wide"
          onClick={onClick}
        >
          {detailsIcon()}
          DETAILS
        </AppNavigationLink>
      </div>
    )
  }
  return null
}
