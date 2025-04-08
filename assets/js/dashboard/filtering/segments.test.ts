import { remapToApiFilters } from '../util/filters'
import {
  formatSegmentIdAsLabelKey,
  getFilterSegmentsByNameInsensitive,
  getSearchToApplySingleSegmentFilter,
  getSegmentNamePlaceholder,
  isSegmentIdLabelKey,
  parseApiSegmentData,
  isListableSegment,
  resolveFilters,
  SegmentType,
  SavedSegment,
  SegmentData,
  canSeeSegmentDetails
} from './segments'
import { Filter } from '../query'
import { PlausibleSite } from '../site-context'
import { Role, UserContextValue } from '../user-context'

describe(`${getFilterSegmentsByNameInsensitive.name}`, () => {
  const unfilteredSegments = [
    { name: 'APAC Region' },
    { name: 'EMEA Region' },
    { name: 'Scandinavia' }
  ]
  it('generates insensitive filter function', () => {
    expect(
      unfilteredSegments.filter(getFilterSegmentsByNameInsensitive('region'))
    ).toEqual([{ name: 'APAC Region' }, { name: 'EMEA Region' }])
  })

  it('ignores preceding and following whitespace', () => {
    expect(
      unfilteredSegments.filter(getFilterSegmentsByNameInsensitive(' scandi '))
    ).toEqual([{ name: 'Scandinavia' }])
  })

  it.each([[undefined], [''], ['   '], ['\n\n']])(
    'generates always matching filter for search value %p',
    (searchValue) => {
      expect(
        unfilteredSegments.filter(
          getFilterSegmentsByNameInsensitive(searchValue)
        )
      ).toEqual(unfilteredSegments)
    }
  )
})

describe(`${getSegmentNamePlaceholder.name}`, () => {
  it('gives readable result', () => {
    const placeholder = getSegmentNamePlaceholder({
      labels: { US: 'United States' },
      filters: [
        ['is', 'country', ['US']],
        ['contains', 'page', ['/blog', `${new Array(250).fill('c').join('')}`]]
      ]
    })

    expect(placeholder).toEqual(
      'Country is United States and Page contains /blog or ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc'
    )
    expect(placeholder).toHaveLength(255)
  })
})

describe('segment labels in URL search params', () => {
  test(`${formatSegmentIdAsLabelKey.name} and ${isSegmentIdLabelKey.name} work`, () => {
    const formatted = formatSegmentIdAsLabelKey(5)
    expect(formatted).toEqual('segment-5')
    expect(isSegmentIdLabelKey(formatted)).toEqual(true)
  })
})

describe(`${parseApiSegmentData.name}`, () => {
  it('correctly formats values stored as API filters in their dashboard format', () => {
    const apiFormatFilters = [
      ['is', 'visit:country', ['PL']],
      ['is', 'event:props:logged_in', ['true']],
      ['has_not_done', ['is', 'event:goal', ['Signup']]]
    ]
    const dashboardFormat = parseApiSegmentData({
      filters: apiFormatFilters,
      labels: { PL: 'Poland' }
    })
    expect(dashboardFormat).toEqual({
      filters: [
        ['is', 'country', ['PL']],
        ['is', 'props:logged_in', ['true']],
        ['has_not_done', 'goal', ['Signup']]
      ],
      labels: { PL: 'Poland' }
    })
    expect(remapToApiFilters(dashboardFormat.filters)).toEqual(apiFormatFilters)
  })
})

describe(`${getSearchToApplySingleSegmentFilter.name}`, () => {
  test('generated search function applies single segment correctly', () => {
    const searchFunction = getSearchToApplySingleSegmentFilter({
      name: 'APAC',
      id: 500
    })
    const existingSearch = {
      date: '2025-02-10',
      filters: [
        ['is', 'country', ['US']],
        ['is', 'page', ['/blog']]
      ],
      labels: { US: 'United States' }
    }
    expect(searchFunction(existingSearch)).toEqual({
      date: '2025-02-10',
      filters: [['is', 'segment', [500]]],
      labels: { 'segment-500': 'APAC' }
    })
  })
})

describe(`${isListableSegment.name}`, () => {
  const site: Pick<PlausibleSite, 'siteSegmentsAvailable'> = {
    siteSegmentsAvailable: true
  }
  const user: UserContextValue = { loggedIn: true, id: 1, role: Role.editor }

  it('should return true for site segment when siteSegmentsAvailable is true', () => {
    const segment = { id: 1, type: SegmentType.site, owner_id: 1 }
    expect(isListableSegment({ segment, site, user })).toBe(true)
  })

  it('should return false for personal segment when user is not logged in', () => {
    const segment = { id: 1, type: SegmentType.personal, owner_id: 1 }
    expect(
      isListableSegment({
        segment,
        site,
        user: { loggedIn: false, role: Role.public, id: null }
      })
    ).toBe(false)
  })

  it('should return true for personal segment when user is the owner', () => {
    const segment = { id: 1, type: SegmentType.personal, owner_id: 1 }
    expect(isListableSegment({ segment, site, user })).toBe(true)
  })

  it('should return false for personal segment when user is not the owner', () => {
    const segment = { id: 1, type: SegmentType.personal, owner_id: 2 }
    expect(isListableSegment({ segment, site, user })).toBe(false)
  })
})

describe(`${resolveFilters.name}`, () => {
  const segmentData: SegmentData = {
    filters: [['is', 'browser', ['Chrome']]],
    labels: {}
  }
  const segments: Array<
    Pick<SavedSegment, 'id'> & { segment_data: SegmentData }
  > = [{ id: 1, segment_data: segmentData }]

  it('should resolve segment filters to their actual filters', () => {
    const resolvedFilters = resolveFilters(
      [
        ['is', 'segment', [1]],
        ['is', 'browser', ['Firefox']]
      ],
      segments
    )
    expect(resolvedFilters).toEqual([
      ...segmentData.filters,
      ['is', 'browser', ['Firefox']]
    ])
  })

  it('should return the original filter if it is not a segment filter', () => {
    const filters: Filter[] = [['is', 'browser', ['Firefox']]]
    const resolvedFilters = resolveFilters(filters, segments)
    expect(resolvedFilters).toEqual(filters)
  })

  it('should return the original filter if the segment is not found', () => {
    const filters: Filter[] = [['is', 'segment', [2]]]
    const resolvedFilters = resolveFilters(filters, segments)
    expect(resolvedFilters).toEqual(filters)
  })

  const cases: Array<{ filters: Filter[] }> = [
    {
      filters: [
        ['is', 'segment', [1]],
        ['is', 'segment', [2]]
      ]
    },
    { filters: [['is', 'segment', [1, 2]]] }
  ]
  it.each(cases)(
    'should throw an error if more than one segment filter is applied, as in %p',
    ({ filters }) => {
      expect(() => resolveFilters(filters, segments)).toThrow(
        'Dashboard can be filtered by only one segment'
      )
    }
  )
})

describe(`${canSeeSegmentDetails.name}`, () => {
  it('should return true if the user is logged in and not a public role', () => {
    const user: UserContextValue = { loggedIn: true, role: Role.admin, id: 1 }
    expect(canSeeSegmentDetails({ user })).toBe(true)
  })

  it('should return false if the user is not logged in', () => {
    const user: UserContextValue = {
      loggedIn: false,
      role: Role.editor,
      id: null
    }
    expect(canSeeSegmentDetails({ user })).toBe(false)
  })

  it('should return false if the user has a public role', () => {
    const user: UserContextValue = { loggedIn: true, role: Role.public, id: 1 }
    expect(canSeeSegmentDetails({ user })).toBe(false)
  })
})
