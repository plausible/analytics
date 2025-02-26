/** @format */

import React from 'react'
import { SavedSegment } from '../filtering/segments'
import { formatDayShort, parseNaiveDate } from '../util/date'

export const SegmentAuthorship = ({
  className,
  owner_name,
  inserted_at,
  updated_at
}: Pick<SavedSegment, 'owner_name' | 'inserted_at' | 'updated_at'> & {
  className?: string
}) => {
  const authorLabel = owner_name

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
