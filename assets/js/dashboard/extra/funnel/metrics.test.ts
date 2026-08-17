import { FunnelResponse, stepMetrics } from './metrics'

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
      conversion_rate_step: '25'
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
})
