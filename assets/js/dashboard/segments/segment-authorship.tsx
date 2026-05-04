import React from 'react'
import { SavedSegmentPublic, SavedSegment } from '../filtering/segments'
import { parseNaiveDate, formatDayShort } from '../util/date'

type SegmentAuthorshipProps = {
  className?: string
  showOnlyPublicData: boolean
  segment: SavedSegmentPublic | SavedSegment
}

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
    <span className={className}>
      <span>
        {`Created at ${formatDayShort(parseNaiveDate(inserted_at))}`}
        {!showUpdatedAt && !!authorLabel && ` by ${authorLabel}`}
      </span>
      {showUpdatedAt && (
        <>
          {' • '}
          <span>
            {`Last updated at ${formatDayShort(parseNaiveDate(updated_at))}`}
            {!!authorLabel && ` by ${authorLabel}`}
          </span>
        </>
      )}
    </span>
  )
}
