import { RevenueMetricValue } from '../../api'

type FunnelStep = {
  label: string
  visitors: number
  dropoff: number
  dropoff_percentage: string
  conversion_rate: string
  conversion_rate_step: string
  // Only steps whose goal is a revenue goal report money, each in its own
  // goal's currency.
  revenue?: RevenueMetricValue | null
  revenue_per_visitor?: RevenueMetricValue | null
}

type FunnelPeriod = {
  steps: FunnelStep[]
  all_visitors: number
  entering_visitors: number
  entering_visitors_percentage: string
  never_entering_visitors: number
  never_entering_visitors_percentage: string
}

export type FunnelResponse = FunnelPeriod & {
  name: string
  strict_order: boolean
  comparison?: FunnelPeriod | null
  date_range?: [string, string]
  comparison_date_range?: [string, string] | null
}

export type StepOutcome = {
  visitors: number
  rate: string
}

export type StepValues = {
  visitors: number
  conversionRate: string
  continued: StepOutcome
  droppedOff: StepOutcome
  revenue: RevenueMetricValue | null
  revenuePerVisitor: RevenueMetricValue | null
}

export type StepMetrics = StepValues & {
  label: string
  comparison: StepValues | null
}

function stepValues(
  funnel: FunnelPeriod,
  step: FunnelStep,
  index: number
): StepValues {
  return {
    visitors: step.visitors,
    conversionRate: step.conversion_rate,
    revenue: step.revenue ?? null,
    revenuePerVisitor: step.revenue_per_visitor ?? null,
    continued:
      index === 0
        ? {
            visitors: funnel.entering_visitors,
            rate: funnel.entering_visitors_percentage
          }
        : { visitors: step.visitors, rate: step.conversion_rate_step },
    droppedOff:
      index === 0
        ? {
            visitors: funnel.never_entering_visitors,
            rate: funnel.never_entering_visitors_percentage
          }
        : { visitors: step.dropoff, rate: step.dropoff_percentage }
  }
}

export function conversionRateChange(
  current: string,
  previous: string
): number {
  return Math.round((Number(current) - Number(previous)) * 10) / 10
}

export function stepMetrics(funnel: FunnelResponse): StepMetrics[] {
  const previous = funnel.comparison

  return funnel.steps.map((step, index) => {
    const previousStep = previous?.steps[index]

    return {
      label: step.label,
      ...stepValues(funnel, step, index),
      comparison:
        previous && previousStep
          ? stepValues(previous, previousStep, index)
          : null
    }
  })
}
