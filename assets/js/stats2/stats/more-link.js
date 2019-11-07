import React from 'react';

export default function MoreLink({site, list, endpoint}) {
  if (list.length >= 5) {
    return (
      <div className="text-center">
        <a href={`${site.domain}/${endpoint}${window.location.search}`}className="font-bold text-sm text-grey-dark hover:text-red transition tracking-wide">
          <svg className="feather mr-1"><use xlinkHref="#feather-maximize" /></svg>
          MORE
        </a>
      </div>
    )
  } else {
    return null
  }
}
