/** @format */

import { DashboardQuery, Filter } from '../query'
import { remapFromApiFilters } from '../util/filters'
import { plainFilterText } from '../util/filter-text'

export enum SegmentType {
  personal = 'personal',
  site = 'site'
}

export type SavedSegment = {
  id: number
  name: string
  type: SegmentType
  owner_id: number
  inserted_at: string
  updated_at: string
}

export type SegmentData = {
  filters: Filter[]
  labels: Record<string, string>
}

const SEGMENT_LABEL_KEY_PREFIX = 'segment-'

export function getFilterSegmentsByNameInsensitive(
  search?: string
): (s: SavedSegment) => boolean {
  return (s) =>
    search?.trim().length
      ? s.name.toLowerCase().includes(search.trim().toLowerCase())
      : true
}

export const getSegmentNamePlaceholder = (query: DashboardQuery) =>
  query.filters
    .reduce(
      (combinedName, filter) =>
        combinedName.length > 100
          ? combinedName
          : `${combinedName}${combinedName.length ? ' and ' : ''}${plainFilterText(query, filter)}`,
      ''
    )
    .slice(0, 255)

export function isSegmentIdLabelKey(labelKey: string): boolean {
  return labelKey.startsWith(SEGMENT_LABEL_KEY_PREFIX)
}

export function formatSegmentIdAsLabelKey(id: number): string {
  return `${SEGMENT_LABEL_KEY_PREFIX}${id}`
}

export const isSegmentFilter = (f: Filter): boolean => f[1] === 'segment'

export const parseApiSegmentData = ({
  filters,
  ...rest
}: SegmentData): SegmentData => ({
  filters: remapFromApiFilters(filters),
  ...rest
})
