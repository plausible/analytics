import React from 'react';
import { Link } from 'react-router-dom'

export default function MoreLink({site, list, endpoint}) {
  if (list.length > 0) {
    return (
      <div className="text-center w-full absolute bottom-0 left-0 pb-3">
        <Link to={`/${encodeURIComponent(site.domain)}/${endpoint}${window.location.search}`} className="leading-snug font-bold text-sm text-gray-500 hover:text-red-500 transition tracking-wide">
          <svg className="feather mr-1" style={{marginTop: '-2px'}} xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3"/></svg>
          MORE
        </Link>
      </div>
    )
  }
  return null
}
