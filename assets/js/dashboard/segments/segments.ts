/** @format */

import { Filter } from '../query'
import { remapFromApiFilters } from '../util/filters'

export enum SegmentType {
  personal = 'personal',
  site = 'site'
}

export type SavedSegment = {
  id: number
  name: string
  type: SegmentType
  owner_id: number
}

export type SegmentData = {
  filters: Filter[]
  labels: Record<string, string>
}

export type EditingSegmentState = {
  /** null means to definitively close the edit mode */
  editingSegment: SavedSegment | null
}

const SEGMENT_LABEL_KEY_PREFIX = 'segment-'

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
