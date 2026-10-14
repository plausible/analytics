import { Filter } from '../dashboard-state'
import { getValueSuggestionsRequest } from './fetch-suggestions'

const site = { domain: 'dummy.site' }

describe(`${getValueSuggestionsRequest.name}`, () => {
  it.each<[Filter, ReturnType<typeof getValueSuggestionsRequest>]>([
    [
      ['is', 'source', ['Google']],
      {
        path: '/api/stats/dummy.site/suggestions/source/',
        additionalFilter: ['is_not', 'source', []]
      }
    ],
    [
      ['is', 'goal', ['Signup']],
      {
        path: '/api/stats/dummy.site/suggestions/goal/',
        additionalFilter: undefined
      }
    ],
    [
      ['is', 'props:author', ['john']],
      {
        path: '/api/stats/dummy.site/suggestions/custom-prop-values/author/',
        additionalFilter: ['is_not', 'props:author', ['(none)']]
      }
    ],
    [['contains', 'page', ['/blog']], null]
  ])('for %p returns %p', (filter, expectedRequest) => {
    expect(getValueSuggestionsRequest(site, filter)).toEqual(expectedRequest)
  })
})
