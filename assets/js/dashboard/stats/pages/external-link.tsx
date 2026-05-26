import React from 'react'
import { ExternalLinkIcon } from '../breakdowns'

export function DetailsExternalLink({
  href,
  isActive
}: {
  href: string | null
  isActive?: boolean
}) {
  return (
    <div className="w-4 min-w-4 self-stretch flex flex-col justify-center">
      {href && (
        <a
          target="_blank"
          rel="noreferrer"
          href={href}
          className={isActive ? 'block' : 'hidden'}
        >
          <ExternalLinkIcon />
        </a>
      )}
    </div>
  )
}

export function IndexExternalLink({
  href,
  isActive
}: {
  href: string
  isActive?: boolean
}) {
  return (
    <a
      target="_blank"
      rel="noreferrer"
      href={href}
      className={
        isActive
          ? 'visible md:invisible md:group-hover/row:visible'
          : 'invisible md:group-hover/row:visible'
      }
    >
      <ExternalLinkIcon />
    </a>
  )
}
