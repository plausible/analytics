export enum AnnotationType {
  personal = 'personal',
  site = 'site'
}

/** This type signifies that the owner can't be shown. */
// type AnnotationOwnershipHidden = { owner_id: null; owner_name: null }

/** This type signifies that the original owner has been removed from the site. */
type AnnotationOwnershipDangling = { owner_id: null; owner_name: null }

type AnnotationOwnership =
  | AnnotationOwnershipDangling
  | { owner_id: number; owner_name: string }

export enum AnnotationGranularity {
  date = 'date',
  minute = 'minute'
}

export type Annotation = {
  datetime: string
  granularity: AnnotationGranularity
  type: AnnotationType
  note: string

  id: number
  /** datetime in site timezone, example 2025-02-26 10:00:00 */
  inserted_at: string
  /** datetime in site timezone, example 2025-02-26 10:00:00 */
  updated_at: string
} & AnnotationOwnership

export type AnnotationPayload = Pick<
  Annotation,
  'note' | 'datetime' | 'granularity' | 'type'
>

export const ANNOTATION_TYPE_LABELS = {
  [AnnotationType.personal]: 'Personal note',
  [AnnotationType.site]: 'Site-wide note'
}
