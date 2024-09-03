/** @format */

import { Metric } from '../stats/reports/metrics'
import {
  OrderBy,
  SortDirection,
  cycleSortDirection,
  findOrderIndex,
  omitOrderByIndex,
  rearrangeOrderBy
} from './use-order-by'

describe(`${findOrderIndex.name}`, () => {
  /* prettier-ignore */
  const cases: [OrderBy, Pick<Metric, 'key'>, number][] = [
    [[], { key: 'anything' }, -1],
    [[['visitors', SortDirection.asc]], { key: 'anything' }, -1],
    [[['bounce_rate', SortDirection.desc], ['visitors', SortDirection.asc]], {key: 'visitors'}, 1]
  ]

  test.each(cases)(
    `in order by %p, the index of metric %p is %p`,
    (orderBy, metric, expectedIndex) => {
      expect(findOrderIndex(orderBy, metric)).toEqual(expectedIndex)
    }
  )
})

describe(`${omitOrderByIndex.name}`, () => {
  /* prettier-ignore */
  const cases: [OrderBy, number, OrderBy][] = [
        [[['visitors', SortDirection.asc]], 0, []],
        [[['bounce_rate', SortDirection.desc], ['visitors', SortDirection.asc]], 1, [['bounce_rate', SortDirection.desc]]],
        [[['a', SortDirection.desc], ['b', SortDirection.asc], ['c', SortDirection.desc]], 1, [['a', SortDirection.desc], ['c', SortDirection.desc]]]
      ]

  test.each(cases)(
    `in order by %p, omitting the index %p yields %p`,
    (orderBy, index, expectedOrderBy) => {
      expect(omitOrderByIndex(orderBy, index)).toEqual(expectedOrderBy)
    }
  )
})

describe(`${cycleSortDirection.name}`, () => {
  test.each([
    [
      null,
      {
        direction: SortDirection.desc,
        hint: 'Press to sort column in descending order'
      }
    ],
    [
      SortDirection.desc,
      {
        direction: SortDirection.asc,
        hint: 'Press to sort column in ascending order'
      }
    ],
    [
      SortDirection.asc,
      {
        direction: null,
        hint: 'Press to remove sorting from column'
      }
    ]
  ])(
    'for current direction %p returns %p',
    (currentDirection, expectedOutput) => {
      expect(cycleSortDirection(currentDirection)).toEqual(expectedOutput)
    }
  )
})

describe(`${rearrangeOrderBy.name}`, () => {
  const cases: [Pick<Metric, 'key'>, OrderBy, OrderBy][] = [
    [{ key: 'visitors' }, [['visitors', SortDirection.asc]], []],
    [
      { key: 'visitors' },
      [['visitors', SortDirection.desc]],
      [['visitors', SortDirection.asc]]
    ],
    [
      { key: 'visit_duration' },
      [['visitors', SortDirection.asc]],
      [['visit_duration', SortDirection.desc]]
    ]
  ]
  it.each(cases)(
    'clicking on %p with order %p yields %p',
    (metric, currentOrderBy, expectedOrderBy) => {
      expect(rearrangeOrderBy(currentOrderBy, metric)).toEqual(expectedOrderBy)
    }
  )
})
