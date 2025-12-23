import { DashboardQuery, Filter } from '../query'
import { cleanLabels, remapFromApiFilters } from '../util/filters'
import { plainFilterText } from '../util/filter-text'
import { AppNavigationTarget } from '../navigation/use-app-navigate'
import { PlausibleSite } from '../site-context'
import { Role, UserContextValue } from '../user-context'

export enum SegmentType {
  personal = 'personal',
  site = 'site'
}

/** keep in sync with Plausible.Segments */
const ROLES_WITH_MAYBE_SITE_SEGMENTS = [Role.admin, Role.editor, Role.owner]
const ROLES_WITH_PERSONAL_SEGMENTS = [
  Role.billing,
  Role.viewer,
  Role.admin,
  Role.editor,
  Role.owner
]

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

export type SavedSegments = Array<
  (SavedSegment | SavedSegmentPublic) & {
    segment_data: SegmentData
  }
>

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

export function formatSegmentIdAsLabelKey(id: number | string): string {
  return `${SEGMENT_LABEL_KEY_PREFIX}${id}`
}

export const isSegmentFilter = (
  filter: Filter
): filter is ['is', 'segment', (number | string)[]] => {
  const [operation, dimension, clauses] = filter
  return operation === 'is' && dimension === 'segment' && Array.isArray(clauses)
}

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

export function getSearchToRemoveSegmentFilter(): Required<AppNavigationTarget>['search'] {
  return (searchRecord) => {
    const updatedFilters = (
      (Array.isArray(searchRecord.filters)
        ? searchRecord.filters
        : []) as Filter[]
    ).filter((f) => !isSegmentFilter(f))
    const currentLabels = searchRecord.labels ?? {}
    return {
      ...searchRecord,
      filters: updatedFilters,
      labels: cleanLabels(updatedFilters, currentLabels)
    }
  }
}

export function getSearchToSetSegmentFilter(
  segment: Pick<SavedSegment, 'id' | 'name'>,
  options: { omitAllOtherFilters?: boolean } = {}
): Required<AppNavigationTarget>['search'] {
  return (searchRecord) => {
    const otherFilters = (
      (Array.isArray(searchRecord.filters)
        ? searchRecord.filters
        : []) as Filter[]
    ).filter((f) => !isSegmentFilter(f))
    const currentLabels = searchRecord.labels ?? {}

    const filters = [
      ['is', 'segment', [segment.id]],
      ...(options.omitAllOtherFilters ? [] : otherFilters)
    ]

    const labels = cleanLabels(filters, currentLabels, 'segment', {
      [formatSegmentIdAsLabelKey(segment.id)]: segment.name
    })
    return {
      ...searchRecord,
      filters,
      labels
    }
  }
}

export const SEGMENT_TYPE_LABELS = {
  [SegmentType.personal]: 'Personal segment',
  [SegmentType.site]: 'Site segment'
}

export function resolveFilters(
  filters: Filter[],
  segments: Array<Pick<SavedSegment, 'id'> & { segment_data: SegmentData }>
): Filter[] {
  let segmentsInFilter = 0
  return filters.flatMap((filter): Filter[] => {
    if (isSegmentFilter(filter)) {
      segmentsInFilter++
      const [_operation, _dimension, clauses] = filter
      if (segmentsInFilter > 1 || clauses.length !== 1) {
        throw new Error('Dashboard can be filtered by only one segment')
      }
      const segment = segments.find(
        (segment) => String(segment.id) == String(clauses[0])
      )
      return segment ? segment.segment_data.filters : [filter]
    } else {
      return [filter]
    }
  })
}

export function canExpandSegment({
  segment,
  user
}: {
  segment: Pick<SavedSegment, 'id' | 'owner_id' | 'type'>
  user: UserContextValue
}) {
  if (
    segment.type === SegmentType.site &&
    user.loggedIn &&
    ROLES_WITH_MAYBE_SITE_SEGMENTS.includes(user.role)
  ) {
    return true
  }

  if (
    segment.type === SegmentType.personal &&
    user.loggedIn &&
    ROLES_WITH_PERSONAL_SEGMENTS.includes(user.role) &&
    user.id === segment.owner_id
  ) {
    return true
  }

  return false
}

export function isListableSegment({
  segment,
  site,
  user
}: {
  segment:
    | Pick<SavedSegment, 'id' | 'type' | 'owner_id'>
    | Pick<SavedSegmentPublic, 'id' | 'type' | 'owner_id'>
  site: Pick<PlausibleSite, 'siteSegmentsAvailable'>
  user: UserContextValue
}) {
  if (segment.type === SegmentType.site && site.siteSegmentsAvailable) {
    return true
  }

  if (segment.type === SegmentType.personal) {
    if (!user.loggedIn || user.id === null || user.role === Role.public) {
      return false
    }
    return segment.owner_id === user.id
  }

  return false
}

export function canSeeSegmentDetails({ user }: { user: UserContextValue }) {
  return user.loggedIn && user.role !== Role.public
}

export function canRemoveFilter(
  filter: Filter,
  limitedToSegment: Pick<SavedSegment, 'id' | 'name'> | null
) {
  if (isSegmentFilter(filter) && limitedToSegment) {
    const [_operation, _dimension, clauses] = filter
    return (
      clauses.length === 1 && String(limitedToSegment.id) === String(clauses[1])
    )
  }
  return true
}

export function findAppliedSegmentFilter({ filters }: { filters: Filter[] }) {
  const segmentFilter = filters.find(isSegmentFilter)
  if (!segmentFilter) {
    return undefined
  }
  const [_operation, _dimension, clauses] = segmentFilter
  if (clauses.length !== 1) {
    throw new Error('Dashboard can be filtered by only one segment')
  }
  return segmentFilter
}
