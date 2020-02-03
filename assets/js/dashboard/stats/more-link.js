import React from 'react';
import { Link } from 'react-router-dom'

export default function MoreLink({site, endpoint}) {
  return (
    <div className="text-center w-full absolute pin-b pin-l p-4">
      <Link to={`/${encodeURIComponent(site.domain)}/${endpoint}${window.location.search}`}className="font-bold text-sm text-grey-dark hover:text-red transition tracking-wide">
        <svg className="feather mr-1"><use xlinkHref="#feather-maximize" /></svg>
        MORE
      </Link>
    </div>
  )
}
