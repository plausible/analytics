/** @format */

import { DashboardQuery, Filter } from '../query'
import { cleanLabels, remapFromApiFilters } from '../util/filters'
import { plainFilterText } from '../util/filter-text'
import { AppNavigationTarget } from '../navigation/use-app-navigate'

export enum SegmentType {
  personal = 'personal',
  site = 'site'
}

/** This type signifies that the owner can't be shown. */
type SegmentOwnershipHidden = { owner_id: null; owner_name: null }

/** This type signifies that the original owner has been removed from the site. */
type SegmentOwnershipDangling = { owner_id: null; owner_name: null }

type SegmentOwnership =
  | SegmentOwnershipDangling
  | { owner_id: number; owner_name: string }

export type SavedSegment = {
  id: number
  name: string
  type: SegmentType
  /** datetime in site timezone, example 2025-02-26 10:00:00 */
  inserted_at: string
  /** datetime in site timezone, example 2025-02-26 10:00:00 */
  updated_at: string
} & SegmentOwnership

export type SavedSegmentPublic = Pick<
  SavedSegment,
  'id' | 'type' | 'name' | 'inserted_at' | 'updated_at'
> &
  SegmentOwnershipHidden

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

export const isSegmentFilter = (f: Filter): f is ['is', 'segment', [number]] =>
  f[0] === 'is' &&
  f[1] === 'segment' &&
  Array.isArray(f[2]) &&
  f[2].length === 1

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

export const SEGMENT_TYPE_LABELS = {
  [SegmentType.personal]: 'Personal segment',
  [SegmentType.site]: 'Site segment'
}
