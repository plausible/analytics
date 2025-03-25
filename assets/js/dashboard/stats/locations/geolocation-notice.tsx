import React from 'react'

export const GeolocationNotice = () => {
  return (
    <div className="max-w-24 sm:max-w-none md:max-w-24 lg:max-w-none text-xs text-gray-500 absolute bottom-0 right-0">
      IP Geolocation by{' '}
      <a
        target="_blank"
        href="https://db-ip.com"
        rel="noreferrer"
        className="text-indigo-600"
      >
        DB-IP
      </a>
    </div>
  )
}
