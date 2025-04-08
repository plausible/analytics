import React from 'react'
import { SavedSegmentPublic, SavedSegment } from '../filtering/segments'
import { dateForSite, formatDayShort } from '../util/date'
import { useSiteContext } from '../site-context'

type SegmentAuthorshipProps = { className?: string } & (
  | { showOnlyPublicData: true; segment: SavedSegmentPublic }
  | { showOnlyPublicData: false; segment: SavedSegment }
)

export function SegmentAuthorship({
  className,
  showOnlyPublicData,
  segment
}: SegmentAuthorshipProps) {
  const site = useSiteContext()
  const authorLabel =
    showOnlyPublicData === true
      ? null
      : (segment.owner_name ?? '(Removed User)')

  const { updated_at, inserted_at } = segment
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
