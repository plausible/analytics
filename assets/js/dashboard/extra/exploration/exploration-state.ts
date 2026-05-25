import { useState, useEffect, useRef, useCallback } from 'react'
import { ApiError } from '../../api'
import * as api from '../../api'
import * as url from '../../util/url'
import { useSiteContext, PlausibleSite } from '../../site-context'
import { DashboardState } from '../../dashboard-state'
import {
  emptyJourney,
  toggleJourneyStep,
  setJourneyActiveFilter,
  clearJourneyFrozen,
  clearJourneyFunnel,
  clearJourneyRateLimit,
  updateJourneyOnSuccess,
  updateJourneyOnError,
  updateJourneyOnRateLimitError,
  JourneyStep,
  Journey,
  JourneySuggestion,
  FunnelStep
} from './journey'
import { DIRECTION, PAGE_FILTER_KEYS, ExplorationDirection } from './constants'

export type ExplorationData = {
  journey: Journey
  direction: ExplorationDirection
  activeLoading: boolean
  layoutKey: number
  rateLimited: boolean
  selectStep: (columnIndex: number, step: JourneyStep | null) => void
  reset: () => void
  retry: () => void
  setDirection: (direction: ExplorationDirection) => void
  setActiveFilter: (filter: string) => void
}

type ExplorationResponse = {
  next: JourneySuggestion[] | null
  funnel: FunnelStep[] | null
} | null

function isRateLimitedError(err: Error): boolean {
  return err instanceof ApiError && err.status === 429
}

// Strip page-related filters from the dashboard state when a journey is
// active - the journey itself defines the page scope.
function dashboardStateForQuery(
  dashboardState: DashboardState,
  steps: JourneyStep[]
): DashboardState {
  if (steps.length === 0) return dashboardState
  return {
    ...dashboardState,
    filters: dashboardState.filters.filter(
      ([_op, key]) => !PAGE_FILTER_KEYS.includes(key)
    )
  }
}

// Serialize steps into the wire format expected by the API.
function stepsToJourneyParam(steps: JourneyStep[]): string {
  return JSON.stringify(
    steps.map(
      ({ name, pathname, includes_subpaths, subpaths_count, is_goal }) => ({
        name,
        pathname,
        includes_subpaths,
        subpaths_count,
        is_goal
      })
    )
  )
}

function fetchNextWithFunnel(
  site: PlausibleSite,
  dashboardState: DashboardState,
  steps: JourneyStep[],
  filter: string,
  direction: ExplorationDirection,
  includeFunnel: boolean
): Promise<ExplorationResponse> {
  return api.post(
    url.apiPath(site, '/exploration/next-with-funnel'),
    dashboardStateForQuery(dashboardState, steps),
    {
      journey: stepsToJourneyParam(steps),
      search_term: filter,
      direction,
      include_funnel: includeFunnel
    }
  )
}

// useExplorationData manages all async data fetching, cancellation, and
// journey state.
export function useExplorationData({
  site,
  dashboardState,
  inViewport
}: {
  site: PlausibleSite
  dashboardState: DashboardState
  inViewport: boolean
}): ExplorationData {
  const {
    explorationMaxJourneySteps: maxJourneySteps,
    explorationJourneyEndEvent: journeyEndEvent
  } = useSiteContext()
  const [journey, setJourney] = useState(emptyJourney)
  const [activeLoading, setActiveLoading] = useState(false)
  const [retryCount, setRetryCount] = useState(0)
  const [directionKey, setDirectionKey] = useState(0)
  // Incremented whenever the dashboardState or site changes so that
  // PathConnectors re-runs its layout effect and recalculates connector
  // geometry against the freshly rendered DOM. Steps alone do not change
  // on a context switch, so without this the SVG paths would be stale.
  const [layoutKey, setLayoutKey] = useState(0)

  // Ref-copies of the previous dependency values so the main effect can detect
  // which dimension changed without adding them to the dep array.
  const prevStepsRef = useRef(journey.steps)
  const prevDirectionRef = useRef(DIRECTION.FORWARD)
  const prevDashboardStateRef = useRef(dashboardState)

  // Incremented on every user-driven journey mutation. Stale async callbacks
  // capture the version at dispatch time and abort if it no longer matches.
  const journeyVersionRef = useRef(0)

  // Direction lives in a ref so that changing it resets state in one render
  // without causing a double-fetch from a direction state update racing with
  // a steps state update.
  const directionRef = useRef(DIRECTION.FORWARD)

  const selectStep = useCallback(
    (columnIndex: number, step: JourneyStep | null) => {
      journeyVersionRef.current++
      setJourney((journey) =>
        toggleJourneyStep({ journey, columnIndex, newStep: step })
      )
    },
    []
  )

  const reset = useCallback(() => {
    ++journeyVersionRef.current
    setActiveLoading(true)
    setJourney(emptyJourney)
  }, [])

  const setDirection = useCallback((newDirection: ExplorationDirection) => {
    if (newDirection === directionRef.current) return
    directionRef.current = newDirection
    ++journeyVersionRef.current
    setJourney(emptyJourney)
    setDirectionKey((k) => k + 1)
  }, [])

  const setActiveFilter = useCallback((filter: string) => {
    setJourney((journey) => setJourneyActiveFilter({ journey, filter }))
  }, [])

  // Frozen candidate lists were fetched against a specific site and dashboard
  // filter context. When either changes the cached candidates become stale, so
  // drop them. We also bump layoutKey so PathConnectors recalculates geometry
  // after the DOM settles. Skip the initial run to avoid clobbering freshly
  // populated state on mount.
  const isFirstContextChangeRef = useRef(true)
  useEffect(() => {
    if (isFirstContextChangeRef.current) {
      isFirstContextChangeRef.current = false
      return
    }
    ++journeyVersionRef.current
    setJourney(clearJourneyFrozen)
    setLayoutKey((k) => k + 1)
  }, [site, dashboardState])

  useEffect(() => {
    if (!inViewport) return

    const currentDirection = directionRef.current
    const steps = journey.steps
    const activeFilter = journey.activeFilter

    if (steps.length >= maxJourneySteps) {
      setActiveLoading(false)
      return
    }

    const journeyChanged =
      prevStepsRef.current !== steps ||
      prevDirectionRef.current !== currentDirection ||
      prevDashboardStateRef.current !== dashboardState

    prevStepsRef.current = steps
    prevDirectionRef.current = currentDirection
    prevDashboardStateRef.current = dashboardState

    // Capture the version at effect-dispatch time so stale responses are
    // discarded if the user mutates the journey before the response arrives.
    const capturedVersion = journeyVersionRef.current
    const isStale = () => journeyVersionRef.current !== capturedVersion

    setActiveLoading(true)

    const includeFunnel = journeyChanged && steps.length > 0

    if (journeyChanged && steps.length === 0) {
      setJourney(clearJourneyFunnel)
    }

    fetchNextWithFunnel(
      site,
      dashboardState,
      steps,
      activeFilter,
      currentDirection,
      includeFunnel
    )
      .then((response) => {
        if (isStale()) return
        setJourney((journey) =>
          updateJourneyOnSuccess({
            journey,
            response,
            includeFunnel,
            journeyEndEvent
          })
        )
      })
      .catch((err) => {
        if (isStale()) return
        if (isRateLimitedError(err)) {
          setJourney((journey) =>
            updateJourneyOnRateLimitError({ journey, includeFunnel })
          )
        } else {
          setJourney((journey) =>
            updateJourneyOnError({ journey, includeFunnel })
          )
        }
      })
      .finally(() => {
        if (!isStale()) setActiveLoading(false)
      })

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    site,
    dashboardState,
    journey.steps,
    journey.activeFilter,
    inViewport,
    retryCount,
    directionKey
  ])
  // direction is intentionally excluded from the dep array. It lives in a ref
  // and resets state, which does appear above, so the state update itself
  // drives the re-run without double-firing.

  const retry = useCallback(() => {
    setJourney(clearJourneyRateLimit)
    setRetryCount((c) => c + 1)
  }, [])

  return {
    journey,
    direction: directionRef.current,
    activeLoading,
    layoutKey,
    rateLimited: journey.rateLimited,
    selectStep,
    reset,
    retry,
    setDirection,
    setActiveFilter
  }
}
