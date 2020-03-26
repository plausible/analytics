import React from 'react';
import { Link } from 'react-router-dom'

export default function MoreLink({site, list, endpoint}) {
  if (list.length > 0) {
    return (
      <div className="text-center w-full absolute bottom-0 left-0 p-4">
        <Link to={`/${encodeURIComponent(site.domain)}/${endpoint}${window.location.search}`} className="leading-snug font-bold text-sm text-gray-500 hover:text-red-500 transition tracking-wide">
          <svg className="feather mr-1" style={{marginTop: '-2px'}}><use xlinkHref="#feather-maximize" /></svg>
          MORE
        </Link>
      </div>
    )
  }
  return null
}
