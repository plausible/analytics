import React from 'react'
import { COUNTRIES_BY_TWO_LETTER_CODE } from './countries'

export const FlagEmoji = ({ countryCode }: { countryCode: string | null }) => {
  if (!countryCode) {
    return null
  }
  const entry = COUNTRIES_BY_TWO_LETTER_CODE[countryCode]
  if (!entry?.flag) {
    return null
  }
  return <span className="mr-1.5">{entry.flag}</span>
}
