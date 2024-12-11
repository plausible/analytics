/** @format */

import { Filter } from '../query'
import {
  encodeURIComponentPermissive,
  isSearchEntryDefined,
  parseFilter,
  parseLabelsEntry,
  parseSearch,
  parseSimpleSearchEntry,
  serializeFilter,
  serializeLabelsEntry,
  serializeSimpleSearchEntry,
  stringifySearch
} from './url-search-params'

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
      const result = encodeURIComponentPermissive(input, ',:/')
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

describe(`${serializeLabelsEntry.name} and decodeURIComponent(${parseLabelsEntry.name}(...)) are opposite of each other`, () => {
  test.each<[[string, string], string]>([
    [['US', 'United States'], 'US,United%20States'],
    [['FR-IDF', 'Île-de-France'], 'FR-IDF,%C3%8Ele-de-France'],
    [['1254661', 'Thāne'], '1254661,Th%C4%81ne']
  ])(
    'entry %p serializes to %p, parses back to original',
    (entry, expected) => {
      const serialized = serializeLabelsEntry(entry)
      expect(serialized).toEqual(expected)
      expect(parseLabelsEntry(decodeURIComponent(serialized))).toEqual(entry)
    }
  )
})

describe(`${serializeFilter.name} and decodeURIComponent(${parseFilter.name}(...)) are opposite of each other`, () => {
  test.each<[Filter, string]>([
    [
      ['contains', 'entry_page', ['/forecast/:city', 'ü']],
      'contains,entry_page,/forecast/:city,%C3%BC'
    ]
  ])(
    'filter %p serializes to %p, parses back to original',
    (filter, expected) => {
      const serialized = serializeFilter(filter)
      expect(serialized).toEqual(expected)
      expect(parseFilter(decodeURIComponent(serialized))).toEqual(filter)
    }
  )
})

describe(`${serializeSimpleSearchEntry.name} and ${parseSimpleSearchEntry.name}`, () => {
  test.each<
    [
      [string, unknown],
      [string, string | boolean | undefined],
      [string, string | boolean] | null
    ]
  >([
    [['undefined-param', undefined], ['undefined-param', undefined], null],
    [['null-param', null], ['null-param', undefined], null],
    [['array-param', ['any-value']], ['array-param', undefined], null],
    [['obj-param', { 'any-key': 'any-value' }], ['obj-param', undefined], null],
    [
      ['date-obj', new Date('2024-01-01T10:00:00.000Z')],
      ['date-obj', undefined],
      null
    ],
    [
      ['page-nr', 5],
      ['page-nr', '5'],
      ['page-nr', '5']
    ],
    [
      ['string-param-resembling-boolean', 'true'],
      ['string-param-resembling-boolean', 'true'],
      ['string-param-resembling-boolean', true]
    ],
    [
      ['match-day-of-week', false],
      ['match-day-of-week', 'false'],
      ['match-day-of-week', false]
    ],
    [
      ['with-imported-data', true],
      ['with-imported-data', 'true'],
      ['with-imported-data', true]
    ],
    [
      ['date-string', '2024-12-10'],
      ['date-string', '2024-12-10'],
      ['date-string', '2024-12-10']
    ]
  ])(
    'entry %p serializes to %p, parses to %p',
    (entry, expectedSerialized, expectedParsedEntry) => {
      const serialized = serializeSimpleSearchEntry(entry)
      expect(serialized).toEqual(expectedSerialized)
      expect(
        serialized[1] === undefined
          ? null
          : parseSimpleSearchEntry(serialized[1])
      ).toEqual(expectedParsedEntry === null ? null : expectedParsedEntry[1])
    }
  )
})

describe(`${stringifySearch.name}`, () => {
  it.each([
    [
      {
        filters: [['is', 'props:browser_language', ['en-US']]]
      },
      '?f=is,props:browser_language,en-US'
    ],
    [
      {
        filters: [
          ['contains', 'utm_term', ['_']],
          ['is', 'screen', ['Desktop', 'Tablet']],
          [
            'is',
            'page',
            ['/open-source/analytics/encoded-hash%23', '/unencoded-hash#']
          ]
        ],
        period: 'custom',
        keybindHint: 'A',
        comparison: 'previous_period',
        match_day_of_week: false,
        from: '2024-08-08',
        to: '2024-08-10'
      },
      '?f=contains,utm_term,_&f=is,screen,Desktop,Tablet&f=is,page,/open-source/analytics/encoded-hash%2523,/unencoded-hash%23&period=custom&keybindHint=A&comparison=previous_period&match_day_of_week=false&from=2024-08-08&to=2024-08-10'
    ],
    [
      {
        filters: [
          ['is', 'props:browser_language', ['en-US']],
          ['is', 'country', ['US']],
          ['is', 'os', ['iOS']],
          ['is', 'os_version', ['17.3', '16.0']],
          ['is', 'page', ['/:dashboard/settings/general']]
        ],
        labels: { US: 'United States' }
      },
      '?f=is,props:browser_language,en-US&f=is,country,US&f=is,os,iOS&f=is,os_version,17.3,16.0&f=is,page,/:dashboard/settings/general&l=US,United%20States'
    ]
  ])('works as expected', (searchRecord, expectedSearchString) => {
    expect(stringifySearch(searchRecord)).toEqual(expectedSearchString)
    expect(parseSearch(expectedSearchString)).toEqual(searchRecord)
  })
})
