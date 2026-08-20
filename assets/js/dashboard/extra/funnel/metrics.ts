type FunnelStep = {
  label: string
  visitors: number
  dropoff: number
  dropoff_percentage: string
  conversion_rate: string
  conversion_rate_step: string
}

export type FunnelResponse = {
  name: string
  strict_order: boolean
  steps: FunnelStep[]
  all_visitors: number
  entering_visitors: number
  entering_visitors_percentage: string
  never_entering_visitors: number
  never_entering_visitors_percentage: string
}

type StepOutcome = {
  visitors: number
  rate: string
}

export type StepMetrics = {
  label: string
  visitors: number
  conversionRate: string
  continued: StepOutcome
  droppedOff: StepOutcome
}

export function stepMetrics(funnel: FunnelResponse): StepMetrics[] {
  return funnel.steps.map((step, index) => ({
    label: step.label,
    visitors: step.visitors,
    conversionRate: step.conversion_rate,
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
  }))
}
