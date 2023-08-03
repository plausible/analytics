import React from 'react';
import { Link } from 'react-router-dom'

function detailsIcon() {
  return (
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
  )
}

function moreIcon() {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      strokeWidth="1.5"
      stroke="currentColor"
      className="w-6 h-6 feather mr-1"
    >
      <path strokeLinecap="round" strokeLinejoin="round" d="M3 4.5h14.25M3 9h9.75M3 13.5h9.75m4.5-4.5v12m0 0l-3.75-3.75M17.25 21L21 17.25" />
    </svg>
  )
}

export default function MoreLink({url, site, list, endpoint, buttonText, className}) {

  if (list.length > 0) {
    return (
      <div className={`w-full text-center ${className ? className : ''}`}>
        <Link
          to={url || `/${encodeURIComponent(site.domain)}/${endpoint}${window.location.search}`}
          // eslint-disable-next-line max-len
          className="leading-snug font-bold text-sm text-gray-500 dark:text-gray-400 hover:text-red-500 dark:hover:text-red-400 transition tracking-wide"
        >
          { buttonText === 'DETAILS' && detailsIcon() }
          { buttonText === 'MORE' && moreIcon() }
          { buttonText }
        </Link>
      </div>
    )
  }
  return null
}
