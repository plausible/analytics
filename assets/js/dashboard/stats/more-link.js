import React from 'react';
import { Link } from 'react-router-dom'

export default function MoreLink({url, site, list, endpoint}) {
  if (list.length > 0) {
    return (
      <div className="text-center w-full py-3 md:pb-3 md:pt-0 md:absolute md:bottom-0 md:left-0">
        <Link
          to={url || `/${encodeURIComponent(site.domain)}/${endpoint}${window.location.search}`}
          // eslint-disable-next-line max-len
          className="leading-snug font-bold text-sm text-gray-500 dark:text-gray-400 hover:text-red-500 dark:hover:text-red-400 transition tracking-wide"
        >
          <svg
            className="feather mr-1"
            style={{marginTop: '-2px'}}
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            {/* eslint-disable-next-line max-len */}
            <path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3" />
          </svg>
          DETAILS
        </Link>
      </div>
    )
  }
  return null
}
