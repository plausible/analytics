import { Interval } from '../stats/graph/intervals'
import { parseUTCDate } from '../util/date'

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

export type PinPosition = { x: number; selectedIndex: number }

export type AnnotationWithPinState = Annotation & {
  isPinned: boolean
  pinPosition: PinPosition | null
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

export const getAnnotationAttribution = (
  annotation: Pick<Annotation, 'type' | 'owner_name'>
): string => {
  if (annotation.type === AnnotationType.site && annotation.owner_name) {
    return annotation.owner_name
  }
  return ANNOTATION_TYPE_LABELS[annotation.type]
}

export const canEditAnnotation = (
  annotation: Pick<Annotation, 'owner_id'>,
  userId: number | null
): boolean => userId !== null && annotation.owner_id === userId

export const getAnnotationTimeLabel = (
  annotation: Pick<Annotation, 'datetime' | 'granularity'>,
  interval: Interval
): string => {
  const dateString = annotation.datetime.substring(0, 'YYYY-MM-DD'.length)
  switch (annotation.granularity) {
    case AnnotationGranularity.date: {
      switch (interval) {
        case Interval.month:
          // floors to closest start of month for the date
          return parseUTCDate(dateString).startOf('month').format('YYYY-MM-DD')
        case Interval.week:
          // floors to closest start of week for the date
          return parseUTCDate(dateString).startOf('week').format('YYYY-MM-DD')
        case Interval.day:
        case Interval.hour:
        case Interval.minute:
          // floors to date
          return dateString
      }
      break
    }
    case AnnotationGranularity.minute: {
      switch (interval) {
        case Interval.month:
          // floors to closest start of month for the date
          return parseUTCDate(dateString).startOf('month').format('YYYY-MM-DD')
        case Interval.week:
          // floors to closest start of week for the date
          return parseUTCDate(dateString).startOf('week').format('YYYY-MM-DD')
        case Interval.day:
          // floors to date
          return dateString
        case Interval.hour: {
          const [dateYYYYMMDD, timeHHMMSS] = annotation.datetime.split('T')
          // floors time to hour
          return `${dateYYYYMMDD} ${timeHHMMSS.substring(0, 'HH'.length)}:00:00`
        }
        case Interval.minute:
          return annotation.datetime.split('T').join(' ')
      }
    }
  }
}

export const groupAnnotationsByTimeLabel = <
  T extends Pick<Annotation, 'datetime' | 'granularity'>
>(
  annotations: T[],
  interval: Interval
): Record<string, T[] | undefined> => {
  return annotations.reduce<Record<string, T[]>>((acc, annotation) => {
    const timeLabel = getAnnotationTimeLabel(annotation, interval)
    return { ...acc, [timeLabel]: [...(acc[timeLabel] ?? []), annotation] }
  }, {})
}

export const enrichAnnotationsWithPinState = (
  annotations: Annotation[],
  pinnedAnnotationIds: Record<number, PinPosition | null>
): AnnotationWithPinState[] =>
  annotations.map((annotation) => {
    const pinPosition = pinnedAnnotationIds[annotation.id] ?? null
    return { ...annotation, isPinned: pinPosition !== null, pinPosition }
  })

export const getAnnotationGranularity = (
  interval: Interval
): AnnotationGranularity => {
  switch (interval) {
    case Interval.minute:
    case Interval.hour:
      return AnnotationGranularity.minute
    case Interval.day:
    case Interval.week:
    case Interval.month:
      return AnnotationGranularity.date
  }
}
