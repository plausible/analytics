// Two steps are identical when their identity fields match.
function stepsEqual(a, b) {
  return (
    a.name === b.name &&
    a.pathname === b.pathname &&
    a.includes_subpaths === b.includes_subpaths
  )
}

function roundedPercentage(value, total) {
  const percentage = (value / total) * 100
  // Rounding to 2 decimal places using Math.round()
  // (https://stackoverflow.com/a/11832950)
  return Math.round((percentage + Number.EPSILON) * 100) / 100
}

// Keep only entries with index < fromIndex, discarding everything at or after.
// Used to truncate frozen candidate snapshots when the journey is shortened.
function truncateFrozenAt(frozen, fromIndex) {
  const result = {}
  for (const key of Object.keys(frozen)) {
    if (Number(key) < fromIndex) result[key] = frozen[key]
  }
  return result
}

// Compute provisional funnel entries for a newly selected step so the UI
// displays sensible values immediately before the API responds.
function provisionalEntry(step, columnIndex, sourceResults, existingFunnel) {
  const match = sourceResults.find(({ step: s }) => stepsEqual(s, step))
  if (!match) return {}

  const firstStepVisitors = existingFunnel[0]?.visitors ?? match.visitors
  const conversionRate = roundedPercentage(match.visitors, firstStepVisitors)
  return {
    [columnIndex]: { visitors: match.visitors, conversion_rate: conversionRate }
  }
}

function deselectStep(journey, columnIndex) {
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

function selectStep(journey, columnIndex, newStep) {
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

function maybeEmptyResults(results, activeFilter, journeyEndEvent) {
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

export function emptyJourney() {
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

export function toggleJourneyStep({ journey, columnIndex, newStep }) {
  if (newStep === null) {
    return deselectStep(journey, columnIndex)
  }

  return selectStep(journey, columnIndex, newStep)
}

export function setJourneyActiveFilter({ journey, filter }) {
  return { ...journey, activeFilter: filter }
}

export function clearJourneyFrozen(journey) {
  return { ...journey, frozen: {} }
}

export function clearJourneyFunnel(journey) {
  return { ...journey, funnel: [] }
}

export function clearJourneyRateLimit(journey) {
  return { ...journey, rateLimited: false }
}

export function updateJourney({ journey, response, includeFunnel, journeyEndEvent }) {
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
    const firstZeroIdx = newFunnel.findIndex((f) => f.visitors === 0)
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
      const synced = currentSteps.map((s, idx) =>
        newFunnel[idx]
          ? { ...s, subpaths_count: newFunnel[idx].step.subpaths_count }
          : s
      )
      // Only replace the steps reference when something actually changed
      // to avoid re-triggering the main effect (steps is a dep array entry).
      const changed = synced.some(
        (s, idx) => s.subpaths_count !== currentSteps[idx].subpaths_count
      )
      if (changed) newJourney.steps = synced
    }
  }
  return newJourney
}
