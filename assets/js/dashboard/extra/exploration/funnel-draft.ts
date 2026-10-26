import type {
  FunnelDefinitionStep,
  FunnelStepInput
} from '../funnel/funnel-api'
import { journeyStepsEqual, JourneyStep } from './journey'
import { DIRECTION, ExplorationDirection } from './constants'

// Maps an explored step onto a saveable funnel step. Goals are referenced
// by id, anything else becomes a dynamic step. Grouped pages are matched
// with a trailing wildcard.
export function journeyStepToFunnelStep(step: JourneyStep): FunnelStepInput {
  if (step.saved_step) {
    return step.saved_step
  } else if (step.is_goal && step.goal_id) {
    return { goal_id: step.goal_id }
  } else if (step.name !== 'pageview') {
    return { event_name: step.name }
  } else if (step.includes_subpaths) {
    return { page_path: `${step.pathname}*` }
  } else {
    return { page_path: step.pathname }
  }
}

// Steps of a journey explored backwards are listed from the end point.
// Funnels always go forward in time.
export function chronologicalSteps(
  steps: JourneyStep[],
  direction: ExplorationDirection
): JourneyStep[] {
  return direction === DIRECTION.BACKWARD ? [...steps].reverse() : steps
}

export function savedStepToJourneyStep(
  step: FunnelDefinitionStep
): JourneyStep {
  const saved_step: FunnelStepInput =
    step.goal_id !== null
      ? { goal_id: step.goal_id }
      : {
          ...(step.event_name !== null
            ? { event_name: step.event_name }
            : { page_path: step.page_path ?? '' }),
          scroll_threshold: step.scroll_threshold,
          custom_props: step.custom_props,
          currency: step.currency
        }

  return {
    label: step.label,
    name: step.event_name ?? 'pageview',
    pathname: step.page_path ?? '',
    includes_subpaths: false,
    subpaths_count: 0,
    is_goal: step.goal_id !== null,
    goal_id: step.goal_id,
    goal_kind: step.goal_kind,
    saved_step
  }
}

// Returns the reason why the steps can't be saved as a funnel, if any.
export function draftInvalidReason(
  steps: JourneyStep[],
  {
    minSteps,
    maxSteps,
    journeyEndEvent
  }: { minSteps: number; maxSteps: number; journeyEndEvent: string }
): string | null {
  if (steps.length < minSteps) {
    return `Select at least ${minSteps} steps to save a funnel`
  }

  if (steps.length > maxSteps) {
    return `A funnel can have at most ${maxSteps} steps`
  }

  if (steps.some((step) => step.name === journeyEndEvent)) {
    return "A funnel can't include the end of a journey"
  }

  const hasDuplicates = steps.some((step, index) =>
    steps.slice(0, index).some((other) => journeyStepsEqual(step, other))
  )

  if (hasDuplicates) {
    return 'A funnel step can only be used once'
  }

  return null
}
