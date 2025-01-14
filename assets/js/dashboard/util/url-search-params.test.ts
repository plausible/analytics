/** @format */

import { Filter } from '../query'
import {
  encodeURIComponentPermissive,
  isSearchEntryDefined,
  getRedirectTarget,
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

describe(`${serializeLabelsEntry.name} and ${parseLabelsEntry.name}(...) are opposite of each other`, () => {
  test.each<[[string, string], string]>([
    [['US', 'United States'], 'US,United%20States'],
    [['FR-IDF', 'Île-de-France'], 'FR-IDF,%C3%8Ele-de-France'],
    [['1254661', 'Thāne'], '1254661,Th%C4%81ne']
  ])(
    'entry %p serializes to %p, parses back to original',
    (entry, expected) => {
      const serialized = serializeLabelsEntry(entry)
      expect(serialized).toEqual(expected)
      expect(parseLabelsEntry(serialized)).toEqual(entry)
    }
  )
})

describe(`${serializeFilter.name} and ${parseFilter.name}(...) are opposite of each other`, () => {
  test.each<[Filter, string]>([
    [
      ['contains', 'entry_page', ['/forecast/:city', ',"\'']],
      "contains,entry_page,/forecast/:city,%2C%22'"
    ],
    [
      ['is', 'props:complex/prop-with-comma-etc,$#%', ['(none)']],
      'is,props:complex/prop-with-comma-etc%2C%24%23%25,(none)'
    ]
  ])(
    'filter %p serializes to %p, parses back to original',
    (filter, expected) => {
      const serialized = serializeFilter(filter)
      expect(serialized).toEqual(expected)
      expect(parseFilter(serialized)).toEqual(filter)
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

describe(`${parseSearch.name}`, () => {
  it.each([
    ['?', {}, ''],
    ['?=&&', {}, ''],
    ['?=undefined', {}, ''],
    ['?foo=', { foo: '' }, '?foo='],
    ['??foo', { '?foo': '' }, '?%3Ffoo='],
    [
      '?f=is,visit:page,/any/page&f',
      { filters: [['is', 'visit:page', ['/any/page']]] },
      '?f=is,visit:page,/any/page'
    ]
  ])(
    'for search string %s, returns search record %p, which in turn stringifies to %s',
    (searchString, expectedSearchRecord, expectedRestringifiedResult) => {
      expect(parseSearch(searchString)).toEqual(expectedSearchRecord)
      expect(stringifySearch(expectedSearchRecord)).toEqual(
        expectedRestringifiedResult
      )
    }
  )
})

describe(`${stringifySearch.name}`, () => {
  it.each([
    [{}, ''],
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

describe(`${getRedirectTarget.name}`, () => {
  it.each([
    [''],
    ['?auth=_Y6YOjUl2beUJF_XzG1hk&theme=light&background=%23ee00ee'],
    ['?keybindHint=Escape&with_imported=true'],
    ['?f=is,page,/blog/:category/:article-name&date=2024-10-10&period=day'],
    ['?f=is,country,US&l=US,United%20States']
  ])('for modern search %p returns null', (search) => {
    expect(
      getRedirectTarget({
        pathname: '/example.com%2Fdeep%2Fpath',
        search
      } as Location)
    ).toBeNull()
  })

  it('returns updated URL for jsonurl style filters (v2), and running the updated value through the function again returns null (no redirect loop)', () => {
    const pathname = '/'
    const search =
      '?filters=((is,exit_page,(/plausible.io)),(is,source,(Brave)),(is,city,(993800)))&labels=(993800:Johannesburg)'
    const expectedUpdatedSearch =
      '?f=is,exit_page,/plausible.io&f=is,source,Brave&f=is,city,993800&l=993800,Johannesburg&r=v2'
    expect(
      getRedirectTarget({
        pathname,
        search
      } as Location)
    ).toEqual(`${pathname}${expectedUpdatedSearch}`)
    expect(
      getRedirectTarget({
        pathname,
        search: expectedUpdatedSearch
      } as Location)
    ).toBeNull()
  })

  it('returns updated URL for page=... style filters (v1), and running the updated value through the function again returns null (no redirect loop)', () => {
    const pathname = '/'
    const search = '?page=/docs'
    const expectedUpdatedSearch = '?f=is,page,/docs&r=v1'
    expect(
      getRedirectTarget({
        pathname,
        search
      } as Location)
    ).toEqual(`${pathname}${expectedUpdatedSearch}`)
    expect(
      getRedirectTarget({
        pathname,
        search: expectedUpdatedSearch
      } as Location)
    ).toBeNull()
  })
})
