import { getAvailableFilterDimensions, serializeApiFilters } from './filters'

const ALL_DIMENSIONS = [
  'browser',
  'browser_version',
  'channel',
  'city',
  'country',
  'entry_page',
  'exit_page',
  'goal',
  'hostname',
  'os',
  'os_version',
  'page',
  'props',
  'referrer',
  'region',
  'screen',
  'segment',
  'source',
  'utm_campaign',
  'utm_content',
  'utm_medium',
  'utm_source',
  'utm_term'
]

const sorted = (dimensions: string[]) => [...dimensions].sort()

describe(`${getAvailableFilterDimensions.name}`, () => {
  it('omits props when props are not available', () => {
    expect(
      sorted(
        getAvailableFilterDimensions({
          propsAvailable: false
        })
      )
    ).toEqual(ALL_DIMENSIONS.filter((dimension) => dimension !== 'props'))
  })

  it('includes props when props are available', () => {
    expect(
      sorted(
        getAvailableFilterDimensions({
          propsAvailable: true
        })
      )
    ).toEqual(ALL_DIMENSIONS)
  })
})

describe(`${serializeApiFilters.name}`, () => {
  it('should prefix filter keys with event: or visit: when appropriate', () => {
    const filters = [
      ['is', 'page', ['/docs', '/blog']],
      ['contains', 'goal', ['Signup']],
      ['contains_not', 'browser', ['chrom'], { case_sensitive: false }],
      ['is', 'country', ['US']],
      ['is_not', 'utm_source', ['google']]
    ]
    expect(serializeApiFilters(filters)).toEqual(
      JSON.stringify([
        ['is', 'event:page', ['/docs', '/blog']],
        ['contains', 'event:goal', ['Signup']],
        ['contains_not', 'visit:browser', ['chrom'], { case_sensitive: false }],
        ['is', 'visit:country', ['US']],
        ['is_not', 'visit:utm_source', ['google']]
      ])
    )
  })

  it('wraps has_not_done goal filters in API format', () => {
    const filters = [['has_not_done', 'goal', ['Signup']]]
    expect(serializeApiFilters(filters)).toEqual(
      JSON.stringify([['has_not_done', ['is', 'event:goal', ['Signup']]]])
    )
  })
})
