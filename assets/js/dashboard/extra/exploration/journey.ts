import { roundedNumberFormatter } from '../../util/number-formatter'

export type JourneyStep = {
  label: string
  name: string
  pathname: string
  includes_subpaths: boolean
  subpaths_count: number
  is_goal: boolean
}

export type JourneySuggestion = {
  step: JourneyStep
  visitors: number
}

export type SelectedSuggestion = {
  step: JourneyStep
  visitors: number | null
  conversion_rate: string | null
}

export type FunnelStep = {
  step: JourneyStep
  visitors: number
  dropoff: number
  dropoff_percentage: number
  conversion_rate: string
  conversion_rate_step: string
}

type ProvisionalFunnelStep = {
  visitors: number
  conversion_rate: string
}

type FrozenSuggestions = { [columnIndex: string]: JourneySuggestion[] }
type ProvisionalFunnelSteps = {
  [columnIndex: string]: ProvisionalFunnelStep
}

export type Journey = {
  steps: JourneyStep[]
  funnel: FunnelStep[]
  activeResults: JourneySuggestion[]
  activeFilter: string
  // list of suggestions the user saw when picking step
  frozen: FrozenSuggestions
  provisional: ProvisionalFunnelSteps
  rateLimited: boolean
}

type JourneyResponse = {
  next: JourneySuggestion[] | null
  funnel: FunnelStep[] | null
} | null

// Keep only entries with index < fromIndex, discarding everything at or after.
// Used to truncate frozen candidate snapshots when the journey is shortened.
function truncateFrozenAt(
  frozen: FrozenSuggestions,
  fromIndex: number
): FrozenSuggestions {
  const result: FrozenSuggestions = {}
  for (const key of Object.keys(frozen)) {
    if (Number(key) < fromIndex) result[key] = frozen[key]
  }
  return result
}

// Compute provisional funnel entries for a newly selected step so the UI
// displays sensible values immediately before the API responds.
function provisionalEntry(
  step: JourneyStep,
  columnIndex: number,
  sourceResults: JourneySuggestion[],
  existingFunnel: FunnelStep[]
): ProvisionalFunnelSteps {
  const match = sourceResults.find(({ step: s }: JourneySuggestion): boolean =>
    journeyStepsEqual(s, step)
  )
  if (!match) return {}

  const firstStepVisitors = existingFunnel[0]?.visitors ?? match.visitors
  const conversionRate = roundedNumberFormatter(
    (match.visitors / firstStepVisitors) * 100
  )

  return {
    [columnIndex]: { visitors: match.visitors, conversion_rate: conversionRate }
  }
}

function deselectStep(journey: Journey, columnIndex: number): Journey {
  // Deselect: truncate journey at columnIndex.
  return {
    ...journey,
    steps: journey.steps.slice(0, columnIndex),
    activeResults: [],
    activeFilter: '',
    frozen: truncateFrozenAt(journey.frozen, columnIndex + 1),
    provisional: {},
    rateLimited: false
  }
}

function selectStep(
  journey: Journey,
  columnIndex: number,
  newStep: JourneyStep
): Journey {
  // Select: determine source results for provisional values.
  const sourceResults =
    columnIndex === journey.steps.length
      ? journey.activeResults
      : (journey.frozen[columnIndex] ?? [])

  const newFrozen =
    columnIndex === journey.steps.length
      ? {
          ...truncateFrozenAt(journey.frozen, columnIndex),
          [columnIndex]: journey.activeResults
        }
      : truncateFrozenAt(journey.frozen, columnIndex + 1)

  return {
    ...journey,
    steps: [...journey.steps.slice(0, columnIndex), newStep],
    activeResults: [],
    activeFilter: '',
    frozen: newFrozen,
    provisional: provisionalEntry(
      newStep,
      columnIndex,
      sourceResults,
      journey.funnel
    ),
    rateLimited: false
  }
}

function maybeEmptyResults(
  results: JourneySuggestion[],
  activeFilter: string,
  journeyEndEvent: string
): JourneySuggestion[] {
  if (
    results.length === 0 ||
    (!activeFilter &&
      results.length === 1 &&
      results[0].step.name === journeyEndEvent)
  ) {
    return []
  } else {
    return results
  }
}

// Build selected suggestion at index on the basis of current steps,
// provisional entries and a funnel.
export function getSelectedSuggestion({
  i,
  steps,
  provisional,
  funnel
}: {
  i: number
  steps: JourneyStep[]
  provisional: ProvisionalFunnelSteps
  funnel: FunnelStep[]
}): SelectedSuggestion | null {
  const step = steps[i] ?? null

  if (step !== null) {
    const visitors = provisional[i]?.visitors ?? funnel[i]?.visitors ?? null
    const conversionRate =
      provisional[i]?.conversion_rate ?? funnel[i]?.conversion_rate ?? null

    return {
      step: step,
      visitors: visitors,
      conversion_rate: conversionRate
    }
  } else {
    return null
  }
}

// Two steps are identical when their identity fields match.
export function journeyStepsEqual(a: JourneyStep, b: JourneyStep): boolean {
  return (
    a.name === b.name &&
    a.pathname === b.pathname &&
    a.includes_subpaths === b.includes_subpaths
  )
}

export function emptyJourney(): Journey {
  return {
    steps: [],
    funnel: [],
    activeResults: [],
    activeFilter: '',
    // list of suggestions the user saw when picking step
    frozen: {},
    provisional: {},
    rateLimited: false
  }
}

export function toggleJourneyStep({
  journey,
  columnIndex,
  newStep
}: {
  journey: Journey
  columnIndex: number
  newStep: JourneyStep | null
}): Journey {
  if (newStep === null) {
    return deselectStep(journey, columnIndex)
  }

  return selectStep(journey, columnIndex, newStep)
}

export function setJourneyActiveFilter({
  journey,
  filter
}: {
  journey: Journey
  filter: string
}): Journey {
  return { ...journey, activeFilter: filter }
}

export function clearJourneyFrozen(journey: Journey): Journey {
  return { ...journey, frozen: {} }
}

export function clearJourneyFunnel(journey: Journey): Journey {
  return { ...journey, funnel: [] }
}

export function clearJourneyRateLimit(journey: Journey): Journey {
  return { ...journey, rateLimited: false }
}

export function updateJourneyOnSuccess({
  journey,
  response,
  includeFunnel,
  journeyEndEvent
}: {
  journey: Journey
  response: JourneyResponse
  includeFunnel: boolean
  journeyEndEvent: string
}): Journey {
  const newJourney = {
    ...journey,
    activeResults: maybeEmptyResults(
      response?.next ?? [],
      journey.activeFilter,
      journeyEndEvent
    ),
    rateLimited: false
  }

  if (includeFunnel) {
    let newFunnel = response?.funnel ?? []
    newJourney.provisional = {}

    // Truncate the funnel at first 0-visitors step.
    // This happens when the dashboard state narrows (e.g. shorter time range)
    // and the existing steps can no longer be fulfilled.
    const firstZeroIdx = newFunnel.findIndex(
      (f: FunnelStep): boolean => f.visitors === 0
    )

    if (firstZeroIdx !== -1) {
      newFunnel = newFunnel.slice(0, firstZeroIdx)
      newJourney.steps = journey.steps.slice(0, firstZeroIdx)
      newJourney.frozen = truncateFrozenAt(journey.frozen, firstZeroIdx)
      newJourney.activeResults = []
    }

    newJourney.funnel = newFunnel

    // Sync subpaths_count on existing steps from the refreshed funnel
    // so that step identity stays consistent with what the API now
    // reports for the current period. Without this, a period change
    // leaves stale subpaths_count values in steps while frozen
    // candidates and new results carry fresh values, causing duplicate
    // entries and double-highlighted rows.
    const currentSteps = newJourney.steps ?? journey.steps
    if (newFunnel.length > 0 && currentSteps.length > 0) {
      const synced = currentSteps.map(
        (s: JourneyStep, idx: number): JourneyStep =>
          newFunnel[idx]
            ? { ...s, subpaths_count: newFunnel[idx].step.subpaths_count }
            : s
      )
      // Only replace the steps reference when something actually changed
      // to avoid re-triggering the main effect (steps is a dep array entry).
      const changed = synced.some(
        (s: JourneyStep, idx: number): boolean =>
          s.subpaths_count !== currentSteps[idx].subpaths_count
      )
      if (changed) newJourney.steps = synced
    }
  }
  return newJourney
}

export function updateJourneyOnRateLimitError({
  journey,
  includeFunnel
}: {
  journey: Journey
  includeFunnel: boolean
}): Journey {
  return {
    ...journey,
    frozen: truncateFrozenAt(journey.frozen, journey.steps.length),
    rateLimited: true,
    activeResults: [],
    ...(includeFunnel ? { provisional: {} } : {})
  }
}

export function updateJourneyOnError({
  journey,
  includeFunnel
}: {
  journey: Journey
  includeFunnel: boolean
}): Journey {
  return {
    ...journey,
    frozen: truncateFrozenAt(journey.frozen, journey.steps.length),
    activeResults: [],
    ...(includeFunnel ? { funnel: [] } : {})
  }
}
