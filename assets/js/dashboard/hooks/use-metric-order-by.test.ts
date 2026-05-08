import { Metric } from '../stats/metrics'
import {
  MetricOrderBy,
  cycleSortDirection,
  getOrderByStorageKey,
  getStoredOrderBy,
  maybeStoreOrderBy,
  rearrangeOrderBy,
  validateOrderBy
} from './use-metric-order-by'

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
  const cases: [Metric, MetricOrderBy, MetricOrderBy][] = [
    ['visitors', [['visitors', 'asc']], [['visitors', 'desc']]],
    ['visitors', [['visitors', 'desc']], [['visitors', 'asc']]],
    ['visit_duration', [['visitors', 'asc']], [['visit_duration', 'desc']]]
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
    [false, [['visitors']], ['visitors']],
    [false, [['visitors', 'b']], ['visitors']],
    [
      false,
      [
        ['visitors', 'desc'],
        ['visitors', 'asc']
      ],
      ['visitors']
    ],
    [true, [['visitors', 'desc']], ['visitors']]
  ])(
    '[%#] returns %p given input %p and sortable metrics %p',
    (expected, input, sortableMetrics) => {
      expect(validateOrderBy(input, sortableMetrics as Metric[])).toBe(expected)
    }
  )
})

describe(`storing detailed report preferred order`, () => {
  const domain = 'any-domain'
  const dimensionLabel = 'Goal'

  it('does not store invalid value', () => {
    maybeStoreOrderBy({
      orderBy: [['total_visitors', 'desc']],
      domain,
      dimensionLabel,
      metrics: ['total_visitors']
    })
    expect(
      localStorage.getItem(getOrderByStorageKey(domain, dimensionLabel))
    ).toBe(null)
  })

  it('falls back to fallbackValue if metric has become unsortable between storing and retrieving', () => {
    maybeStoreOrderBy({
      orderBy: [['visitors', 'desc']],
      domain,
      dimensionLabel,
      metrics: ['visitors']
    })
    const inStorage = localStorage.getItem(
      getOrderByStorageKey(domain, dimensionLabel)
    )
    expect(inStorage).toBe('[["visitors","desc"]]')
    expect(
      getStoredOrderBy({
        domain,
        dimensionLabel,
        metrics: ['total_visitors'],
        fallbackValue: [['visitors', 'desc']]
      })
    ).toEqual([['visitors', 'desc']])
  })

  it('retrieves stored value correctly', () => {
    const input: MetricOrderBy = [['visitors', 'asc']]
    localStorage.setItem(
      getOrderByStorageKey(domain, dimensionLabel),
      JSON.stringify(input)
    )
    expect(
      getStoredOrderBy({
        domain,
        dimensionLabel,
        metrics: ['visitors'],
        fallbackValue: [['visitors', 'desc']]
      })
    ).toEqual(input)
  })
})
