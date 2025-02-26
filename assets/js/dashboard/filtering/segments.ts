/** @format */

import { DashboardQuery, Filter } from '../query'
import { cleanLabels, remapFromApiFilters } from '../util/filters'
import { plainFilterText } from '../util/filter-text'
import { AppNavigationTarget } from '../navigation/use-app-navigate'

export enum SegmentType {
  personal = 'personal',
  site = 'site'
}

export type SavedSegment = {
  id: number
  name: string
  type: SegmentType
  owner_id: number
  owner_name: string
  /** datetime in site timezone, example 2025-02-26 10:00:00 */
  inserted_at: string
  /** datetime in site timezone, example 2025-02-26 10:00:00 */
  updated_at: string
}

export type SavedPublicSiteSegment = Pick<
  SavedSegment,
  'id' | 'type' | 'name' | 'inserted_at' | 'updated_at'
>

export type SegmentDataFromApi = {
  filters: unknown[]
  labels: Record<string, string>
}

/** In this type, filters are parsed to dashboard format */
export type SegmentData = {
  filters: Filter[]
  labels: Record<string, string>
}

const SEGMENT_LABEL_KEY_PREFIX = 'segment-'

export function handleSegmentResponse(
  segment: SavedSegment & {
    segment_data: SegmentDataFromApi
  }
): SavedSegment & { segment_data: SegmentData } {
  return {
    ...segment,
    segment_data: parseApiSegmentData(segment.segment_data)
  }
}

export function getFilterSegmentsByNameInsensitive(
  search?: string
): (s: Pick<SavedSegment, 'name'>) => boolean {
  return (s) =>
    search?.trim().length
      ? s.name.toLowerCase().includes(search.trim().toLowerCase())
      : true
}

export const getSegmentNamePlaceholder = (
  query: Pick<DashboardQuery, 'labels' | 'filters'>
) =>
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
}: {
  filters: unknown[]
  labels: Record<string, string>
}): SegmentData => ({
  filters: remapFromApiFilters(filters),
  ...rest
})

export function getSearchToApplySingleSegmentFilter(
  segment: Pick<SavedSegment, 'id' | 'name'>
): Required<AppNavigationTarget>['search'] {
  return (search) => {
    const filters = [['is', 'segment', [segment.id]]]
    const labels = cleanLabels(filters, {}, 'segment', {
      [formatSegmentIdAsLabelKey(segment.id)]: segment.name
    })
    return {
      ...search,
      filters,
      labels
    }
  }
}
