/** @format */

import { getAvailableFilterModals, serializeApiFilters } from './filters'

describe(`${getAvailableFilterModals.name}`, () => {
  it('gives limited object when props and segments are not available', () => {
    expect(
      getAvailableFilterModals({
        propsAvailable: false,
        flags: { saved_segments: null }
      })
    ).toEqual({
      browser: ['browser', 'browser_version'],
      goal: ['goal'],
      hostname: ['hostname'],
      location: ['country', 'region', 'city'],
      os: ['os', 'os_version'],
      page: ['page', 'entry_page', 'exit_page'],
      screen: ['screen'],
      source: ['source', 'channel', 'referrer'],
      utm: [
        'utm_medium',
        'utm_source',
        'utm_campaign',
        'utm_term',
        'utm_content'
      ]
    })
  })

  it('gives full object when props and segments are available', () => {
    expect(
      getAvailableFilterModals({
        propsAvailable: true,
        flags: { saved_segments: true }
      })
    ).toEqual({
      browser: ['browser', 'browser_version'],
      goal: ['goal'],
      hostname: ['hostname'],
      location: ['country', 'region', 'city'],
      os: ['os', 'os_version'],
      page: ['page', 'entry_page', 'exit_page'],
      screen: ['screen'],
      source: ['source', 'channel', 'referrer'],
      utm: [
        'utm_medium',
        'utm_source',
        'utm_campaign',
        'utm_term',
        'utm_content'
      ],
      props: ['props'],
      segment: ['segment']
    })
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
