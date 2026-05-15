import { Metric } from '../stats/reports/metrics'
import {
  OrderBy,
  cycleSortDirection,
  findOrderIndex,
  getOrderByStorageKey,
  getStoredOrderBy,
  maybeStoreOrderBy,
  rearrangeOrderBy,
  validateOrderBy
} from './use-order-by-legacy'

describe(`${findOrderIndex.name}`, () => {
  /* prettier-ignore */
  const cases: [OrderBy, Pick<Metric, 'key'>, number][] = [
    [[], { key: 'anything' }, -1],
    [[['visitors', 'asc']], { key: 'anything' }, -1],
    [[['bounce_rate', 'desc'], ['visitors', 'asc']], {key: 'bounce_rate'}, 0],
    [[['bounce_rate', 'desc'], ['visitors', 'asc']], {key: 'visitors'}, 1]
  ]

  test.each(cases)(
    `[%#] in order by %p, the index of metric %p is %p`,
    (orderBy, metric, expectedIndex) => {
      expect(findOrderIndex(orderBy, metric)).toEqual(expectedIndex)
    }
  )
})

describe(`${cycleSortDirection.name}`, () => {
  test.each([
    [
      null,
      {
        direction: 'desc',
        hint: 'Press to sort column in descending order'
      }
    ],
    [
      'desc',
      {
        direction: 'asc',
        hint: 'Press to sort column in ascending order'
      }
    ],
    [
      'asc',
      {
        direction: 'desc',
        hint: 'Press to sort column in descending order'
      }
    ]
  ] as const)(
    'for current direction %p returns %p',
    (currentDirection, expectedOutput) => {
      expect(cycleSortDirection(currentDirection)).toEqual(expectedOutput)
    }
  )
})

describe(`${rearrangeOrderBy.name}`, () => {
  const cases: [Pick<Metric, 'key'>, OrderBy, OrderBy][] = [
    [{ key: 'visitors' }, [['visitors', 'asc']], [['visitors', 'desc']]],
    [{ key: 'visitors' }, [['visitors', 'desc']], [['visitors', 'asc']]],
    [
      { key: 'visit_duration' },
      [['visitors', 'asc']],
      [['visit_duration', 'desc']]
    ]
  ]
  it.each(cases)(
    `[%#] clicking on %p yields expected order`,
    (metric, currentOrderBy, expectedOrderBy) => {
      expect(rearrangeOrderBy(currentOrderBy, metric)).toEqual(expectedOrderBy)
    }
  )
})

describe(`${validateOrderBy.name}`, () => {
  test.each([
    [false, '', []],
    [false, [], []],
    [false, [['a']], [{ key: 'a' }]],
    [false, [['a', 'b']], [{ key: 'a' }]],
    [
      false,
      [
        ['a', 'desc'],
        ['a', 'asc']
      ],
      [{ key: 'a' }]
    ],
    [true, [['a', 'desc']], [{ key: 'a' }]]
  ])(
    '[%#] returns %p given input %p and sortable metrics %p',
    (expected, input, sortableMetrics) => {
      expect(validateOrderBy(input, sortableMetrics)).toBe(expected)
    }
  )
})

describe(`storing detailed report preferred order`, () => {
  const domain = 'any-domain'
  const reportInfo = { dimensionLabel: 'Goal' }

  it('does not store invalid value', () => {
    maybeStoreOrderBy({
      orderBy: [['foo', 'desc']],
      domain,
      reportInfo,
      metrics: [{ key: 'foo', sortable: false }]
    })
    expect(localStorage.getItem(getOrderByStorageKey(domain, reportInfo))).toBe(
      null
    )
  })

  it('falls back to fallbackValue if metric has become unsortable between storing and retrieving', () => {
    maybeStoreOrderBy({
      orderBy: [['c', 'desc']],
      domain,
      reportInfo,
      metrics: [{ key: 'c', sortable: true }]
    })
    const inStorage = localStorage.getItem(
      getOrderByStorageKey(domain, reportInfo)
    )
    expect(inStorage).toBe('[["c","desc"]]')
    expect(
      getStoredOrderBy({
        domain,
        reportInfo,
        metrics: [{ key: 'c', sortable: false }],
        fallbackValue: [['visitors', 'desc']]
      })
    ).toEqual([['visitors', 'desc']])
  })

  it('retrieves stored value correctly', () => {
    const input = [['any-column', 'asc']]
    localStorage.setItem(
      getOrderByStorageKey(domain, reportInfo),
      JSON.stringify(input)
    )
    expect(
      getStoredOrderBy({
        domain,
        reportInfo,
        metrics: [{ key: 'any-column', sortable: true }],
        fallbackValue: [['visitors', 'desc']]
      })
    ).toEqual(input)
  })
})
