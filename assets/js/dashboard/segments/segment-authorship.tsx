/** @format */

import React from 'react'
import { SavedSegment } from '../filtering/segments'
import { PlausibleSite, useSiteContext } from '../site-context'
import { formatDayShort, parseUTCDate } from '../util/date'

const getAuthorLabel = (
  site: Pick<PlausibleSite, 'members'>,
  owner_id: number
) => {
  if (!site.members) {
    return ''
  }

  if (!owner_id || !site.members[owner_id]) {
    return '(Removed User)'
  }

  // if (owner_id === user.id) {
  //   return 'You'
  // }

  return site.members[owner_id]
}

export const SegmentAuthorship = ({
  className,
  owner_id,
  inserted_at,
  updated_at
}: SavedSegment & {
  className?: string
}) => {
  const site = useSiteContext()

  const authorLabel = getAuthorLabel(site, owner_id)

  const showUpdatedAt = updated_at !== inserted_at

  return (
    <div className={className}>
      <div>
        {`Created at ${formatDayShort(parseUTCDate(inserted_at))}`}
        {!showUpdatedAt && !!authorLabel && ` by ${authorLabel}`}
      </div>
      {showUpdatedAt && (
        <div>
          {`Last updated at ${formatDayShort(parseUTCDate(updated_at))}`}
          {!!authorLabel && ` by ${authorLabel}`}
        </div>
      )}
    </div>
  )
}
