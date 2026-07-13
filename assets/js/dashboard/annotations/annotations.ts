import { Interval } from '../stats/graph/intervals'
import { Role, UserContextValue } from '../user-context'
import {
  formatDayShort,
  formatTime,
  is12HourClock,
  parseUTCDate
} from '../util/date'

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

// the DB side limit is 255, but this looks better in the UI
export const NOTE_MAX_LENGTH = 250

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
  [AnnotationType.site]: 'Site note'
}

export const getAnnotationAttribution = (
  annotation: Pick<Annotation, 'type' | 'owner_name'>
): string => {
  if (annotation.type === AnnotationType.site && annotation.owner_name) {
    return annotation.owner_name
  }
  return ANNOTATION_TYPE_LABELS[annotation.type]
}

export const getAttributionDateLabel = (
  annotation: Pick<Annotation, 'datetime' | 'granularity'>
): string => {
  const date = parseUTCDate(annotation.datetime)
  const dayLabel = formatDayShort(date)
  if (annotation.granularity === AnnotationGranularity.minute) {
    const time = formatTime(date, {
      use12HourClock: is12HourClock(),
      includeMinutes: true
    })
    return `${dayLabel} ${time}`
  }
  return dayLabel
}

/** keep in sync with Plausible.Annotations */
const ROLES_WITH_MAYBE_SITE_ANNOTATIONS = [Role.admin, Role.editor, Role.owner]
const ROLES_WITH_PERSONAL_ANNOTATIONS = [
  Role.billing,
  Role.viewer,
  Role.admin,
  Role.editor,
  Role.owner
]

export function canEditAnnotation({
  annotation,
  user
}: {
  annotation: Pick<Annotation, 'type' | 'owner_id'>
  user: UserContextValue
}) {
  if (
    annotation.type === AnnotationType.site &&
    user.loggedIn &&
    ROLES_WITH_MAYBE_SITE_ANNOTATIONS.includes(user.role)
  ) {
    return true
  }

  if (
    annotation.type === AnnotationType.personal &&
    user.loggedIn &&
    ROLES_WITH_PERSONAL_ANNOTATIONS.includes(user.role) &&
    user.id === annotation.owner_id
  ) {
    return true
  }

  return false
}

export function canShowAddAnnotationButton(props: {
  user: UserContextValue
  siteAnnotationsAvailable: boolean
}) {
  return (
    canAddAnnotation({ type: AnnotationType.personal, ...props }) ||
    canAddAnnotation({ type: AnnotationType.site, ...props })
  )
}

export function canAddAnnotation({
  type,
  user,
  siteAnnotationsAvailable
}: {
  type: AnnotationType
  user: UserContextValue
  siteAnnotationsAvailable: boolean
}) {
  if (
    type === AnnotationType.site &&
    user.loggedIn &&
    ROLES_WITH_MAYBE_SITE_ANNOTATIONS.includes(user.role) &&
    siteAnnotationsAvailable
  ) {
    return true
  }

  if (
    type === AnnotationType.personal &&
    user.loggedIn &&
    ROLES_WITH_PERSONAL_ANNOTATIONS.includes(user.role)
  ) {
    return true
  }

  return false
}

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

export const getApiFormattedPayload = ({
  granularity,
  datetime,
  ...payload
}: AnnotationPayload) => {
  switch (granularity) {
    case AnnotationGranularity.date:
      return { date: datetime, granularity, ...payload }
    case AnnotationGranularity.minute:
      return { datetime, granularity, ...payload }
  }
}
