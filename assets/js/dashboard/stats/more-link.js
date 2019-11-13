import React from 'react';
import { Link } from 'react-router-dom'

export default function MoreLink({site, list, endpoint}) {
  if (list.length >= 5) {
    return (
      <div className="text-center">
        <Link to={`/${site.domain}/${endpoint}${window.location.search}`}className="font-bold text-sm text-grey-dark hover:text-red transition tracking-wide">
          <svg className="feather mr-1"><use xlinkHref="#feather-maximize" /></svg>
          MORE
        </Link>
      </div>
    )
  } else {
    return null
  }
}
