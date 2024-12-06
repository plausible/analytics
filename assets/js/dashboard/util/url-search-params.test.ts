/** @format */

import JsonURL from '@jsonurl/jsonurl'
import {
  encodeSearchParamEntry,
  encodeURIComponentPermissive,
  isSearchEntryDefined,
  parseSearch,
  parseSearchFragment,
  stringifySearch,
  stringifySearchEntry
} from './url'

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

describe(`${encodeURIComponentPermissive.name}`, () => {
  it.each<[string, string]>([
    ['10.00.00/1', '10.00.00/1'],
    ['#hashtag', '%23hashtag'],
    ['100$ coupon', '100%24%20coupon'],
    ['Visit /any/page', 'Visit%20/any/page'],
    ['A,B,C', 'A,B,C'],
    ['props:colon/forward/slash/signs', 'props:colon/forward/slash/signs'],
    ['https://example.com/path', 'https://example.com/path']
  ])(
    'when input is %p, returns %s and decodes back to input',
    (input, expected) => {
      const result = encodeURIComponentPermissive(input)
      expect(result).toBe(expected)
      expect(decodeURIComponent(result)).toBe(input)
    }
  )
})

describe(`${isSearchEntryDefined.name}`, () => {
  it.each<[[string, string | undefined], boolean]>([
    [['key', undefined], false],
    [['key', 'value'], true],
    [['key', ''], true],
    [['anotherKey', 'undefined'], true]
  ])('when entry is %p, returns %s', (entry, expected) => {
    const result = isSearchEntryDefined(entry)
    expect(result).toBe(expected)
  })
})

describe(`${stringifySearchEntry.name}`, () => {
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
    const result = stringifySearchEntry(input)
    expect(result).toEqual(expected)
  })
})

describe(`${encodeSearchParamEntry.name}`, () => {
  it.each<[[string, string], string]>([
    [
      ['labels', '(3448439:S%C3%A3o+Paulo,US:United+States)'],
      'labels=(3448439:S%25C3%25A3o%2BPaulo,US:United%2BStates)'
    ]
  ])('when input is %p, returns %s', (input, expected) => {
    const result = encodeSearchParamEntry(input)
    expect(result).toBe(expected)
  })
})

describe(`${parseSearchFragment.name}`, () => {
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
      const result = parseSearchFragment(searchStringFragment)
      expect(result).toEqual(expected)
    }
  )
})

describe(`${parseSearch.name}`, () => {
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
    const result = parseSearch(searchString)
    expect(result).toEqual(expected)
  })
})

describe(`${stringifySearch.name} and ${parseSearch.name} are inverses of each other`, () => {
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
    `input %p is returned for ${stringifySearch.name}(${parseSearch.name}(input))`,
    (searchString) => {
      const searchRecord = parseSearch(searchString)
      const reStringifiedSearch = stringifySearch(searchRecord)
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
    `for input %p, ${stringifySearch.name}(input) returns %p and ${parseSearch.name}(${stringifySearch.name}(input)) returns the original input`,
    (searchRecord, expected) => {
      const searchString = stringifySearch(searchRecord)
      const parsedSearchRecord = parseSearch(searchString)
      expect(parsedSearchRecord).toEqual(searchRecord)
      expect(searchString).toEqual(expected)
    }
  )
})
