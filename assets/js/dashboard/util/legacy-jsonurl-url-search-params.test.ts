/** @format */

import JsonURL from '@jsonurl/jsonurl'
import {
  legacyParseSearch,
  legacyParseSearchFragment,
  legacyStringifySearch,
  legacyStringifySearchEntry
} from './legacy-jsonurl-url-search-params'

beforeEach(() => {
  // Silence logs in tests
  jest.spyOn(console, 'error').mockImplementation(jest.fn())
})

describe('using json URL parsing with URLSearchParams intermediate', () => {
  it.each([['#'], ['&'], ['=']])('throws on special symbol %p', (s) => {
    const searchString = `?param=${encodeURIComponent(s)}`
    expect(() =>
      JsonURL.parse(new URLSearchParams(searchString).get('param')!)
    ).toThrow()
  })
})

describe(`${legacyStringifySearchEntry.name}`, () => {
  it.each<[[string, unknown], [string, string | undefined]]>([
    [
      ['any-key', {}],
      ['any-key', undefined]
    ],
    [
      ['any-key', []],
      ['any-key', undefined]
    ],
    [
      ['any-key', null],
      ['any-key', undefined]
    ],
    [
      ['period', 'realtime'],
      ['period', 'realtime']
    ],
    [
      ['page', 10],
      ['page', '10']
    ],
    [
      ['labels', { US: 'United States', 3448439: 'São Paulo' }],
      ['labels', '(3448439:S%C3%A3o+Paulo,US:United+States)']
    ],
    [
      ['filters', [['is', 'props:foo:bar', ['one', 'two']]]],
      ['filters', "((is,'props:foo:bar',(one,two)))"]
    ]
  ])('when input is %p, returns %p', (input, expected) => {
    const result = legacyStringifySearchEntry(input)
    expect(result).toEqual(expected)
  })
})

describe(`${legacyParseSearchFragment.name}`, () => {
  it.each([
    ['', null],
    ['("foo":)', null],
    ['(invalid', null],
    ['null', null],

    ['123', 123],
    ['string', 'string'],
    ['item=#', 'item=#'],
    ['item%3D%23', 'item=#'],

    ['(any:(number:1))', { any: { number: 1 } }],
    ['(any:(number:1.001))', { any: { number: 1.001 } }],
    ["(any:(string:'1.001'))", { any: { string: '1.001' } }],

    // Non-JSON strings that should return as string
    ['undefined', 'undefined'],
    ['not_json', 'not_json'],
    ['plainstring', 'plainstring'],
    ['a|b', 'a|b'],
    ['foo bar#', 'foo bar#']
  ])(
    'when searchStringFragment is %p, returns %p',
    (searchStringFragment, expected) => {
      const result = legacyParseSearchFragment(searchStringFragment)
      expect(result).toEqual(expected)
    }
  )
})

describe(`${legacyParseSearch.name}`, () => {
  it.each([
    ['', {}],
    ['?', {}],
    [
      '?arr=(1,2)',
      {
        arr: [1, 2]
      }
    ],
    ['?key1=value1&key2=', { key1: 'value1', key2: null }],
    ['?key1=value1&key2=value2', { key1: 'value1', key2: 'value2' }],
    [
      '?key1=(foo:bar)&filters=((is,screen,(Mobile,Desktop)))',
      {
        key1: { foo: 'bar' },
        filters: [['is', 'screen', ['Mobile', 'Desktop']]]
      }
    ],
    [
      '?filters=((is,country,(US)))&labels=(US:United%2BStates)',
      {
        filters: [['is', 'country', ['US']]],
        labels: {
          US: 'United States'
        }
      }
    ]
  ])('when searchString is %p, returns %p', (searchString, expected) => {
    const result = legacyParseSearch(searchString)
    expect(result).toEqual(expected)
  })
})

describe(`${legacyStringifySearch.name} and ${legacyParseSearch.name} are inverses of each other`, () => {
  it.each([
    ["?filters=((is,'props:browser_language',(en-US)))"],
    [
      '?filters=((contains,utm_term,(_)),(is,screen,(Desktop,Tablet)),(is,page,(/open-source-website-analytics)))&period=custom&keybindHint=A&comparison=previous_period&match_day_of_week=false&from=2024-08-08&to=2024-08-10'
    ],
    [
      "?filters=((is,'props:browser_language',(en-US)),(is,country,(US)),(is,os,(iOS)),(is,os_version,('17.3')),(is,page,('/:dashboard/settings/general')))&labels=(US:United%2BStates)"
    ],
    [
      '?filters=((is,utm_source,(hackernewsletter)),(is,utm_campaign,(profile)))&period=day&keybindHint=D'
    ]
  ])(
    `input %p is returned for ${legacyParseSearch.name}(${legacyParseSearch.name}(input))`,
    (searchString) => {
      const searchRecord = legacyParseSearch(searchString)
      const reStringifiedSearch = legacyStringifySearch(searchRecord)
      expect(reStringifiedSearch).toEqual(searchString)
    }
  )

  it.each([
    // Corresponding test cases for objects parsed from realistic URLs

    [
      {
        filters: [['is', 'props:browser_language', ['en-US']]]
      },
      "?filters=((is,'props:browser_language',(en-US)))"
    ],
    [
      {
        filters: [
          ['contains', 'utm_term', ['_']],
          ['is', 'screen', ['Desktop', 'Tablet']],
          ['is', 'page', ['/open-source/analytics/encoded-hash%23']]
        ],
        period: 'custom',
        keybindHint: 'A',
        comparison: 'previous_period',
        match_day_of_week: false,
        from: '2024-08-08',
        to: '2024-08-10'
      },
      '?filters=((contains,utm_term,(_)),(is,screen,(Desktop,Tablet)),(is,page,(%252Fopen-source%252Fanalytics%252Fencoded-hash%252523)))&period=custom&keybindHint=A&comparison=previous_period&match_day_of_week=false&from=2024-08-08&to=2024-08-10'
    ],
    [
      {
        filters: [
          ['is', 'props:browser_language', ['en-US']],
          ['is', 'country', ['US']],
          ['is', 'os', ['iOS']],
          ['is', 'os_version', ['17.3']],
          ['is', 'page', ['/:dashboard/settings/general']]
        ],
        labels: { US: 'United States' }
      },
      "?filters=((is,'props:browser_language',(en-US)),(is,country,(US)),(is,os,(iOS)),(is,os_version,('17.3')),(is,page,('/:dashboard/settings/general')))&labels=(US:United%2BStates)"
    ],
    [
      {
        filters: [
          ['is', 'utm_source', ['hackernewsletter']],
          ['is', 'utm_campaign', ['profile']]
        ],
        period: 'day',
        keybindHint: 'D'
      },
      '?filters=((is,utm_source,(hackernewsletter)),(is,utm_campaign,(profile)))&period=day&keybindHint=D'
    ]
  ])(
    `for input %p, ${legacyStringifySearch.name}(input) returns %p and ${legacyParseSearch.name}(${legacyStringifySearch.name}(input)) returns the original input`,
    (searchRecord, expected) => {
      const searchString = legacyStringifySearch(searchRecord)
      const parsedSearchRecord = legacyParseSearch(searchString)
      expect(parsedSearchRecord).toEqual(searchRecord)
      expect(searchString).toEqual(expected)
    }
  )
})
