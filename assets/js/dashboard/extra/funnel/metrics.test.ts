import { FunnelResponse, conversionRateChange, stepMetrics } from './metrics'

const funnel: FunnelResponse = {
  name: 'Checkout',
  strict_order: false,
  all_visitors: 250,
  entering_visitors: 100,
  entering_visitors_percentage: '40',
  never_entering_visitors: 150,
  never_entering_visitors_percentage: '60',
  steps: [
    {
      label: 'Visit /products',
      visitors: 100,
      dropoff: 0,
      dropoff_percentage: '0',
      conversion_rate: '100',
      conversion_rate_step: '100'
    },
    {
      label: 'Add to cart',
      visitors: 60,
      dropoff: 40,
      dropoff_percentage: '40',
      conversion_rate: '60',
      conversion_rate_step: '60'
    },
    {
      label: 'Purchase',
      visitors: 15,
      dropoff: 45,
      dropoff_percentage: '75',
      conversion_rate: '15',
      conversion_rate_step: '25',
      revenue: {
        short: '$1.2K',
        long: '$1,200.00',
        value: 1200,
        currency: 'USD'
      },
      revenue_per_visitor: {
        short: '$80.0',
        long: '$80.00',
        value: 80,
        currency: 'USD'
      }
    }
  ]
}

const comparison: NonNullable<FunnelResponse['comparison']> = {
  all_visitors: 200,
  entering_visitors: 80,
  entering_visitors_percentage: '40',
  never_entering_visitors: 120,
  never_entering_visitors_percentage: '60',
  steps: [
    {
      label: 'Visit /products',
      visitors: 80,
      dropoff: 0,
      dropoff_percentage: '0',
      conversion_rate: '100',
      conversion_rate_step: '100'
    },
    {
      label: 'Add to cart',
      visitors: 40,
      dropoff: 40,
      dropoff_percentage: '50',
      conversion_rate: '50',
      conversion_rate_step: '50'
    },
    {
      label: 'Purchase',
      visitors: 8,
      dropoff: 32,
      dropoff_percentage: '80',
      conversion_rate: '10',
      conversion_rate_step: '20',
      revenue: {
        short: '$800.0',
        long: '$800.00',
        value: 800,
        currency: 'USD'
      },
      revenue_per_visitor: {
        short: '$100.0',
        long: '$100.00',
        value: 100,
        currency: 'USD'
      }
    }
  ]
}

describe('stepMetrics()', () => {
  it('gives one entry per step', () => {
    expect(stepMetrics(funnel).map(({ label }) => label)).toEqual([
      'Visit /products',
      'Add to cart',
      'Purchase'
    ])
  })

  it('compares the first step against everyone who saw the site', () => {
    const [firstStep] = stepMetrics(funnel)

    expect(firstStep.continued).toEqual({ visitors: 100, rate: '40' })
    expect(firstStep.droppedOff).toEqual({ visitors: 150, rate: '60' })
  })

  it('compares a later step against the visitors of the previous step', () => {
    const [, secondStep, thirdStep] = stepMetrics(funnel)

    expect(secondStep.continued).toEqual({ visitors: 60, rate: '60' })
    expect(secondStep.droppedOff).toEqual({ visitors: 40, rate: '40' })
    expect(thirdStep.continued).toEqual({ visitors: 15, rate: '25' })
    expect(thirdStep.droppedOff).toEqual({ visitors: 45, rate: '75' })
  })

  it('keeps the visitors and the conversion rate of every step', () => {
    expect(
      stepMetrics(funnel).map(({ visitors, conversionRate }) => [
        visitors,
        conversionRate
      ])
    ).toEqual([
      [100, '100'],
      [60, '60'],
      [15, '15']
    ])
  })

  it('gives no entries for a funnel without steps', () => {
    expect(stepMetrics({ ...funnel, steps: [] })).toEqual([])
  })

  it('leaves out the comparison when the funnel has none', () => {
    expect(stepMetrics(funnel).map(({ comparison }) => comparison)).toEqual([
      null,
      null,
      null
    ])
  })

  it('takes the comparison values from the matching comparison step', () => {
    const [firstStep, , thirdStep] = stepMetrics({ ...funnel, comparison })

    expect(firstStep.comparison).toEqual({
      visitors: 80,
      conversionRate: '100',
      continued: { visitors: 80, rate: '40' },
      droppedOff: { visitors: 120, rate: '60' },
      revenue: null,
      revenuePerVisitor: null
    })
    expect(thirdStep.comparison).toEqual({
      visitors: 8,
      conversionRate: '10',
      continued: { visitors: 8, rate: '20' },
      droppedOff: { visitors: 32, rate: '80' },
      revenue: {
        short: '$800.0',
        long: '$800.00',
        value: 800,
        currency: 'USD'
      },
      revenuePerVisitor: {
        short: '$100.0',
        long: '$100.00',
        value: 100,
        currency: 'USD'
      }
    })
  })

  it('gives no revenue for the steps that are not revenue goals', () => {
    const [firstStep, secondStep] = stepMetrics(funnel)

    expect([firstStep, secondStep].map(({ revenue }) => revenue)).toEqual([
      null,
      null
    ])
  })

  it('keeps the revenue of a step whose goal is a revenue goal', () => {
    const [, , thirdStep] = stepMetrics(funnel)

    expect(thirdStep.revenue).toEqual({
      short: '$1.2K',
      long: '$1,200.00',
      value: 1200,
      currency: 'USD'
    })
    expect(thirdStep.revenuePerVisitor).toEqual({
      short: '$80.0',
      long: '$80.00',
      value: 80,
      currency: 'USD'
    })
  })

  it('keeps the current values next to the comparison values', () => {
    const [firstStep] = stepMetrics({ ...funnel, comparison })

    expect(firstStep.visitors).toBe(100)
    expect(firstStep.continued).toEqual({ visitors: 100, rate: '40' })
  })
})

describe('conversionRateChange()', () => {
  it('gives the difference in percentage points', () => {
    expect(conversionRateChange('60.8', '52.7')).toBe(8.1)
  })

  it('is zero when the rates match', () => {
    expect(conversionRateChange('100', '100')).toBe(0)
  })

  it('is negative when the rate fell', () => {
    expect(conversionRateChange('10', '15')).toBe(-5)
  })
})
