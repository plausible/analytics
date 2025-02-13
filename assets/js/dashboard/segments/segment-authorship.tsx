/** @format */

import React from 'react'
import { SavedSegment } from '../filtering/segments'
import { PlausibleSite, useSiteContext } from '../site-context'
import { dateForSite, formatDayShort } from '../util/date'

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
}: Pick<SavedSegment, 'owner_id' | 'inserted_at' | 'updated_at'> & {
  className?: string
}) => {
  const site = useSiteContext()

  const authorLabel = getAuthorLabel(site, owner_id)

  const showUpdatedAt = updated_at !== inserted_at

  return (
    <div className={className}>
      <div>
        {`Created at ${formatDayShort(dateForSite(inserted_at, site))}`}
        {!showUpdatedAt && !!authorLabel && ` by ${authorLabel}`}
      </div>
      {showUpdatedAt && (
        <div>
          {`Last updated at ${formatDayShort(dateForSite(updated_at, site))}`}
          {!!authorLabel && ` by ${authorLabel}`}
        </div>
      )}
    </div>
  )
}
