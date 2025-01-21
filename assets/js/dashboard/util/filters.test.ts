import { serializeApiFilters } from './filters'

describe('serializeApiFilters', () => {
  it('should prefix filter keys with event: or visit: when appropriate', () => {
    const filters = [
      ['is', 'page', ['/docs', '/blog']],
      ['contains', 'goal', ['Signup']],
      ['contains_not', 'browser', ['chrom'], { case_sensitive: false }],
      ['is', 'country', ['US']],
      ['is_not', 'utm_source', ['google']]
    ]
    expect(serializeApiFilters(filters)).toEqual(JSON.stringify([
      ['is', 'event:page', ['/docs', '/blog']],
      ['contains', 'event:goal', ['Signup']],
      ['contains_not', 'visit:browser', ['chrom'], { case_sensitive: false }],
      ['is', 'visit:country', ['US']],
      ['is_not', 'visit:utm_source', ['google']]
    ]))
  })

  it('wraps has_not_done goal filters in API format', () => {
    const filters = [
      ['has_not_done', 'goal', ['Signup']]
    ]
    expect(serializeApiFilters(filters)).toEqual(JSON.stringify([
      ['has_not_done', ['is', 'event:goal', ['Signup']]]
    ]))
  })
})
