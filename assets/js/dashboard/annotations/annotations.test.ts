import {
  AnnotationGranularity,
  AnnotationType,
  canAddAnnotation,
  canEditAnnotation,
  getAnnotationAttribution,
  getAnnotationGranularity,
  getAnnotationTimeLabel,
  groupAnnotationsByTimeLabel
} from './annotations'
import { Interval } from '../stats/graph/intervals'
import { Role, UserContextValue } from '../user-context'

const loggedInUser = (role: Role, id: number = 42): UserContextValue => ({
  loggedIn: true,
  id,
  role,
  team: { identifier: null, hasConsolidatedView: false }
})

const publicUser: UserContextValue = {
  loggedIn: false,
  id: null,
  role: Role.public,
  team: { identifier: null, hasConsolidatedView: false }
}

describe(`${getAnnotationAttribution.name}`, () => {
  it('returns the owner name for a site annotation with an owner', () => {
    expect(
      getAnnotationAttribution({
        type: AnnotationType.site,
        owner_name: 'Alice'
      })
    ).toBe('Alice')
  })

  it('returns "Site note" for a site annotation with a dangling owner', () => {
    expect(
      getAnnotationAttribution({
        type: AnnotationType.site,
        owner_name: null
      })
    ).toBe('Site note')
  })

  it('returns "Personal note" for a personal annotation regardless of owner (we assume personal notes are served only to the author)', () => {
    expect(
      getAnnotationAttribution({
        type: AnnotationType.personal,
        owner_name: 'Alice'
      })
    ).toBe('Personal note')
  })
})

describe(`${canAddAnnotation.name}`, () => {
  it.each([[Role.admin], [Role.editor], [Role.owner]])(
    'allows adding a site annotation if the user is logged in, in role %p, and the site-annotations feature is available',
    (role) => {
      expect(
        canAddAnnotation({
          type: AnnotationType.site,
          user: loggedInUser(role),
          siteAnnotationsAvailable: true
        })
      ).toBe(true)
    }
  )

  it.each([[Role.admin], [Role.editor], [Role.owner]])(
    'forbids adding a site annotation in role %p when the feature is unavailable (billing gate)',
    (role) => {
      expect(
        canAddAnnotation({
          type: AnnotationType.site,
          user: loggedInUser(role),
          siteAnnotationsAvailable: false
        })
      ).toBe(false)
    }
  )

  it.each([[Role.viewer], [Role.billing]])(
    'forbids adding a site annotation in role %p even when the feature is available',
    (role) => {
      expect(
        canAddAnnotation({
          type: AnnotationType.site,
          user: loggedInUser(role),
          siteAnnotationsAvailable: true
        })
      ).toBe(false)
    }
  )

  it.each([
    [Role.viewer],
    [Role.billing],
    [Role.editor],
    [Role.admin],
    [Role.owner]
  ])(
    'allows adding a personal annotation in role %p regardless of site-annotations availability',
    (role) => {
      expect(
        canAddAnnotation({
          type: AnnotationType.personal,
          user: loggedInUser(role),
          siteAnnotationsAvailable: true
        })
      ).toBe(true)
      expect(
        canAddAnnotation({
          type: AnnotationType.personal,
          user: loggedInUser(role),
          siteAnnotationsAvailable: false
        })
      ).toBe(true)
    }
  )

  it.each([[AnnotationType.personal], [AnnotationType.site]])(
    'forbids the public role from adding %s annotations',
    (type) => {
      expect(
        canAddAnnotation({
          type,
          user: publicUser,
          siteAnnotationsAvailable: true
        })
      ).toBe(false)
    }
  )
})

describe(`${canEditAnnotation.name}`, () => {
  // Mirrors `can_update_one?` (and `get_one`'s personal-note filter) in
  // lib/plausible/annotations/annotations.ex.

  it.each([[Role.admin], [Role.editor], [Role.owner]])(
    'allows editing a site annotation if the user is logged in and in role %p',
    (role) => {
      expect(
        canEditAnnotation({
          annotation: { type: AnnotationType.site, owner_id: 1 },
          user: loggedInUser(role, 1)
        })
      ).toBe(true)
    }
  )

  it('allows editing site annotations authored by other users', () => {
    expect(
      canEditAnnotation({
        annotation: { type: AnnotationType.site, owner_id: 222 },
        user: loggedInUser(Role.owner, 111)
      })
    ).toBe(true)
  })

  it('allows editing a site annotation whose original author was removed (owner_id nulled)', () => {
    expect(
      canEditAnnotation({
        annotation: { type: AnnotationType.site, owner_id: null },
        user: loggedInUser(Role.admin)
      })
    ).toBe(true)
  })

  it.each([[Role.viewer], [Role.billing]])(
    'forbids editing site annotations in role %p',
    (role) => {
      expect(
        canEditAnnotation({
          annotation: { type: AnnotationType.site, owner_id: 1 },
          user: loggedInUser(role, 1)
        })
      ).toBe(false)
    }
  )

  it.each([
    [Role.viewer],
    [Role.billing],
    [Role.editor],
    [Role.admin],
    [Role.owner]
  ])(
    'allows editing a personal annotation that belongs to the user when in role %p',
    (role) => {
      expect(
        canEditAnnotation({
          annotation: { type: AnnotationType.personal, owner_id: 1 },
          user: loggedInUser(role, 1)
        })
      ).toBe(true)
    }
  )

  it('forbids even site owners from editing the personal annotations of other users', () => {
    expect(
      canEditAnnotation({
        annotation: { type: AnnotationType.personal, owner_id: 222 },
        user: loggedInUser(Role.owner, 111)
      })
    ).toBe(false)
  })

  it.each([[AnnotationType.personal], [AnnotationType.site]])(
    'forbids the public role from editing %s annotations',
    (type) => {
      expect(
        canEditAnnotation({
          annotation: { type, owner_id: null },
          user: publicUser
        })
      ).toBe(false)
    }
  )
})

describe(`${getAnnotationGranularity.name}`, () => {
  it.each<[Interval, AnnotationGranularity]>([
    [Interval.minute, AnnotationGranularity.minute],
    [Interval.hour, AnnotationGranularity.minute],
    [Interval.day, AnnotationGranularity.date],
    [Interval.week, AnnotationGranularity.date],
    [Interval.month, AnnotationGranularity.date]
  ])('maps interval %s to granularity %s', (interval, granularity) => {
    expect(getAnnotationGranularity(interval)).toBe(granularity)
  })
})

describe(`${getAnnotationTimeLabel.name}`, () => {
  // 2025-02-26 is a Wednesday
  const dateAnnotation = {
    datetime: '2025-02-26',
    granularity: AnnotationGranularity.date
  }

  it.each<[Interval, string]>([
    [Interval.minute, '2025-02-26'],
    [Interval.hour, '2025-02-26'],
    [Interval.day, '2025-02-26'],
    [Interval.week, '2025-02-24'],
    [Interval.month, '2025-02-01']
  ])(
    `date-granularity annotation on ${dateAnnotation.datetime} bucketed to %s yields %s`,
    (interval, expected) => {
      expect(getAnnotationTimeLabel(dateAnnotation, interval)).toBe(expected)
    }
  )

  const minuteAnnotation = {
    datetime: '2025-02-26T10:30:00',
    granularity: AnnotationGranularity.minute
  }
  it.each<[Interval, string]>([
    [Interval.month, '2025-02-01'],
    [Interval.week, '2025-02-24'],
    [Interval.day, '2025-02-26'],
    [Interval.hour, '2025-02-26 10:00:00'],
    [Interval.minute, '2025-02-26 10:30:00']
  ])(
    `minute granularity annotation with datetime ${minuteAnnotation.datetime} bucketed to %s yields %s`,
    (interval, expected) => {
      expect(getAnnotationTimeLabel(minuteAnnotation, interval)).toBe(expected)
    }
  )
})

describe(`${groupAnnotationsByTimeLabel.name}`, () => {
  const dateGranularity = AnnotationGranularity.date
  const annotations = [
    { id: 1, datetime: '2025-02-24 00:00:00', granularity: dateGranularity }, // Mon
    { id: 2, datetime: '2025-02-26 00:00:00', granularity: dateGranularity }, // Wed (same week)
    { id: 3, datetime: '2025-03-05 00:00:00', granularity: dateGranularity } // following month
  ]

  it('groups annotations by day when the interval is day', () => {
    const grouped = groupAnnotationsByTimeLabel(annotations, Interval.day)

    expect(Object.keys(grouped).sort()).toEqual([
      '2025-02-24',
      '2025-02-26',
      '2025-03-05'
    ])
    expect(grouped['2025-02-24']!.map((a) => a.id)).toEqual([1])
    expect(grouped['2025-02-26']!.map((a) => a.id)).toEqual([2])
    expect(grouped['2025-03-05']!.map((a) => a.id)).toEqual([3])
  })

  it('collapses annotations from the same week into one bucket', () => {
    const grouped = groupAnnotationsByTimeLabel(annotations, Interval.week)

    expect(Object.keys(grouped).sort()).toEqual(['2025-02-24', '2025-03-03'])
    expect(grouped['2025-02-24']!.map((a) => a.id)).toEqual([1, 2])
    expect(grouped['2025-03-03']!.map((a) => a.id)).toEqual([3])
  })

  it('collapses annotations from the same month into one bucket', () => {
    const grouped = groupAnnotationsByTimeLabel(annotations, Interval.month)

    expect(Object.keys(grouped).sort()).toEqual(['2025-02-01', '2025-03-01'])
    expect(grouped['2025-02-01']!.map((a) => a.id)).toEqual([1, 2])
    expect(grouped['2025-03-01']!.map((a) => a.id)).toEqual([3])
  })

  it('preserves insertion order within a bucket', () => {
    const sameDay = [
      { id: 10, datetime: '2025-02-26 08:00:00', granularity: dateGranularity },
      { id: 11, datetime: '2025-02-26 09:00:00', granularity: dateGranularity },
      { id: 12, datetime: '2025-02-26 10:00:00', granularity: dateGranularity }
    ]

    const grouped = groupAnnotationsByTimeLabel(sameDay, Interval.day)

    expect(grouped['2025-02-26']!.map((a) => a.id)).toEqual([10, 11, 12])
  })

  it('returns an empty object when there are no annotations', () => {
    expect(
      groupAnnotationsByTimeLabel(
        [] as { datetime: string; granularity: AnnotationGranularity }[],
        Interval.day
      )
    ).toEqual({})
  })
})
