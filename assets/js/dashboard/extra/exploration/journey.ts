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
