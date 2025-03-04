/** @format */

import React from 'react'
import { SavedSegmentPublic, SavedSegment } from '../filtering/segments'
import { formatDayShort, parseNaiveDate } from '../util/date'

type SegmentAuthorshipProps = { className?: string } & (
  | { showOnlyPublicData: true; segment: SavedSegmentPublic }
  | { showOnlyPublicData: false; segment: SavedSegment }
)

export function SegmentAuthorship({
  className,
  showOnlyPublicData,
  segment
}: SegmentAuthorshipProps) {
  const authorLabel =
    showOnlyPublicData === true
      ? null
      : (segment.owner_name ?? '(Removed User)')

  const { updated_at, inserted_at } = segment
  const showUpdatedAt = updated_at !== inserted_at

  return (
    <div className={className}>
      <div>
        {`Created at ${formatDayShort(parseNaiveDate(inserted_at))}`}
        {!showUpdatedAt && !!authorLabel && ` by ${authorLabel}`}
      </div>
      {showUpdatedAt && (
        <div>
          {`Last updated at ${formatDayShort(parseNaiveDate(updated_at))}`}
          {!!authorLabel && ` by ${authorLabel}`}
        </div>
      )}
    </div>
  )
}
