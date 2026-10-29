import { Filter, FilterClauseLabels } from '../dashboard-state'
import { plainFilterText } from './filter-text'

describe('plainFilterText()', () => {
  it.each<[Filter, FilterClauseLabels, string]>([
    [['is', 'page', ['/docs', '/blog']], {}, 'Page is /docs or /blog'],
    [
      ['is', 'country', ['US']],
      { US: 'United States' },
      'Country is United States'
    ],
    [['is', 'goal', ['Signup']], {}, 'Goal is Signup'],
    [
      ['is', 'props:browser_language', ['en-US']],
      {},
      "Property 'browser_language' is en-US"
    ],
    [
      ['has_not_done', 'goal', ['Signup', 'Login']],
      {},
      'Goal is not Signup or Login'
    ],
    [['is', 'source', []], {}, 'Source is']
  ])(
    'when filter is %p and labels are %p, returns %p',
    (filter, labels, expectedPlainText) => {
      expect(plainFilterText({ labels }, filter)).toBe(expectedPlainText)
    }
  )
})
