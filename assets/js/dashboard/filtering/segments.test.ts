/** @format */

import { remapToApiFilters } from '../util/filters'
import {
  formatSegmentIdAsLabelKey,
  getFilterSegmentsByNameInsensitive,
  getSegmentNamePlaceholder,
  isSegmentIdLabelKey,
  parseApiSegmentData
} from './segments'

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
