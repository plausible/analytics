/* @format */
import React from 'react'

export const GeolocationNotice = () => {
  return (
    <span className="text-xs text-gray-500 absolute bottom-4 right-3">
      IP Geolocation by{' '}
      <a
        target="_blank"
        href="https://db-ip.com"
        rel="noreferrer"
        className="text-indigo-600"
      >
        DB-IP
      </a>
    </span>
  )
}
