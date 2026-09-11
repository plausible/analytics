/**
 * @prettier
 */
import React from 'react'
import classNames from 'classnames'

const siteIconClassName = 'shrink-0 size-5.5 rounded-md'

/**
 * A site is drawn as its favicon, proxied through PlausibleWeb.Favicon. Sites
 * without a favicon get priv/site_favicon_placeholder.svg from that plug, in
 * answer to `placeholder=site`.
 */
export const Favicon = ({ domain }: { domain: string }) => (
  <img
    aria-hidden="true"
    alt=""
    src={`/favicon/sources/${encodeURIComponent(domain)}?placeholder=site`}
    onError={(e) => {
      const target = e.target as HTMLImageElement
      target.onerror = null
      target.src = '/favicon/sources/placeholder?placeholder=site'
    }}
    referrerPolicy="no-referrer"
    className={siteIconClassName}
  />
)

/**
 * The same drawing as priv/site_favicon_placeholder.svg in indigo, so the
 * geometry of the two must change together.
 */
export const ConsolidatedViewIcon = () => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 20 20"
    aria-hidden="true"
    className={classNames(siteIconClassName, 'text-white')}
  >
    <rect width="20" height="20" rx="5" className="fill-indigo-600" />
    <rect
      x=".5"
      y=".5"
      width="19"
      height="19"
      rx="4.5"
      fill="none"
      strokeWidth="1.8"
      className="stroke-white/15"
    />
    <g
      transform="translate(3 3) scale(.5833)"
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.8"
    >
      <path d="M22 12H2M12 22c5.714-5.442 5.714-14.558 0-20M12 22C6.286 16.558 6.286 7.442 12 2" />
      <path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10Z" />
    </g>
  </svg>
)
