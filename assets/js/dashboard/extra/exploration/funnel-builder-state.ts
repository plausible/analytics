import { useState, useEffect, useRef, useCallback } from 'react'
import { ApiError } from '../../api'
import * as api from '../../api'
import * as url from '../../util/url'
import { PlausibleSite } from '../../site-context'
import { DashboardState } from '../../dashboard-state'
import { FunnelResponse, FunnelType } from '../funnel/metrics'
import {
  emptyJourney,
  toggleJourneyStep,
  setJourneyActiveFilter,
  journeyStepsEqual,
  FunnelStep,
  Journey,
  JourneyStep,
  JourneySuggestion
} from './journey'
import { journeyStepToFunnelStep } from './funnel-draft'
import { PAGE_FILTER_KEYS } from './constants'

const PREVIEW_DEBOUNCE_MS = 300

export type FunnelBuilderData = {
  journey: Journey
  activeLoading: boolean
  previewLoading: boolean
  previewError: string | null
  rateLimited: boolean
  candidatesFailed: boolean
  layoutKey: number
  selectStep: (columnIndex: number, step: JourneyStep | null) => void
  setActiveFilter: (filter: string) => void
  retry: () => void
}

// Funnels can't be evaluated with page or goal filters applied,
// as these would interfere with the steps themselves.
function dashboardStateForFunnel(
  dashboardState: DashboardState
): DashboardState {
  return {
    ...dashboardState,
    filters: dashboardState.filters.filter(
      ([_op, key]) => !PAGE_FILTER_KEYS.includes(key) && key !== 'goal'
    )
  }
}

export function droppedFunnelFilters(dashboardState: DashboardState): boolean {
  return dashboardState.filters.some(
    ([_op, key]) => PAGE_FILTER_KEYS.includes(key) || key === 'goal'
  )
}

function errorMessage(error: unknown): string {
  if (
    error instanceof ApiError &&
    typeof error.payload === 'object' &&
    error.payload !== null &&
    'level' in error.payload &&
    error.payload.level === 'normal'
  ) {
    return error.message
  }

  return 'The funnel preview could not be loaded'
}

function isRateLimitedError(error: unknown): boolean {
  return error instanceof ApiError && error.status === 429
}

function toFunnelSteps(
  steps: JourneyStep[],
  response: FunnelResponse
): FunnelStep[] {
  return response.steps.map((funnelStep, index) => ({
    step: steps[index],
    visitors: funnelStep.visitors,
    dropoff: funnelStep.dropoff,
    dropoff_percentage: Number(funnelStep.dropoff_percentage),
    conversion_rate: funnelStep.conversion_rate,
    conversion_rate_step: funnelStep.conversion_rate_step
  }))
}

// A page typed into the search box can be used as a step, even when it
// has no visits yet, e.g. a page that's about to be launched.
export function typedPageStep(filter: string): JourneyStep | null {
  const pathname = filter.trim()

  if (!pathname.startsWith('/') || /\s/.test(pathname)) return null

  return {
    label: pathname,
    name: 'pageview',
    pathname,
    includes_subpaths: false,
    subpaths_count: 0,
    is_goal: false
  }
}

// useFunnelBuilderData drives composing a funnel to save. Unlike journey
// exploration, candidate steps don't depend on previously selected steps,
// while the numbers shown for selected steps come from evaluating the
// funnel itself, the same way a saved funnel is evaluated.
export function useFunnelBuilderData({
  site,
  dashboardState,
  initialSteps,
  funnelType,
  maxSteps
}: {
  site: PlausibleSite
  dashboardState: DashboardState
  initialSteps: JourneyStep[]
  funnelType: FunnelType
  maxSteps: number
}): FunnelBuilderData {
  const [journey, setJourney] = useState<Journey>(() => ({
    ...emptyJourney(),
    steps: initialSteps
  }))
  const [candidates, setCandidates] = useState<JourneySuggestion[] | null>(null)
  const [activeLoading, setActiveLoading] = useState(true)
  const [previewLoading, setPreviewLoading] = useState(false)
  const [previewError, setPreviewError] = useState<string | null>(null)
  const [rateLimited, setRateLimited] = useState(false)
  const [candidatesFailed, setCandidatesFailed] = useState(false)
  const [retryCount, setRetryCount] = useState(0)
  const [layoutKey, setLayoutKey] = useState(0)

  // Candidates only depend on the dashboard state and search term,
  // so they are cached for as long as the dashboard state stays the same.
  const candidatesCacheRef = useRef(new Map<string, JourneySuggestion[]>())

  useEffect(() => {
    candidatesCacheRef.current.clear()
    setLayoutKey((key) => key + 1)
  }, [site, dashboardState])

  const selectStep = useCallback(
    (columnIndex: number, step: JourneyStep | null) => {
      setJourney((journey) => {
        const updated = toggleJourneyStep({
          journey,
          columnIndex,
          newStep: step
        })
        // Only a first step's suggestion count tells how many reach it, later
        // ones wait for the funnel to be evaluated
        const provisional: Journey['provisional'] = {}
        if (updated.provisional[0]) provisional[0] = updated.provisional[0]
        return { ...updated, provisional }
      })
    },
    []
  )

  const setActiveFilter = useCallback((filter: string) => {
    setJourney((journey) => setJourneyActiveFilter({ journey, filter }))
  }, [])

  const retry = useCallback(() => {
    setRateLimited(false)
    setCandidatesFailed(false)
    setRetryCount((count) => count + 1)
  }, [])

  const filter = journey.activeFilter
  const atMaxSteps = journey.steps.length >= maxSteps

  useEffect(() => {
    if (atMaxSteps) {
      setActiveLoading(false)
      return
    }

    const cached = candidatesCacheRef.current.get(filter)
    if (cached) {
      setCandidates(cached)
      setActiveLoading(false)
      return
    }

    let cancelled = false
    setActiveLoading(true)

    api
      .post(
        url.apiPath(site, '/funnels/candidates'),
        dashboardStateForFunnel(dashboardState),
        { search_term: filter }
      )
      .then((response: { next: JourneySuggestion[] }) => {
        if (cancelled) return
        candidatesCacheRef.current.set(filter, response.next)
        setCandidatesFailed(false)
        setCandidates(response.next)
      })
      .catch((error) => {
        if (cancelled) return
        if (isRateLimitedError(error)) {
          setRateLimited(true)
        } else {
          setCandidatesFailed(true)
        }
        setCandidates([])
      })
      .finally(() => {
        if (!cancelled) setActiveLoading(false)
      })

    return () => {
      cancelled = true
    }
  }, [site, dashboardState, filter, atMaxSteps, retryCount])

  // Candidates already picked for other steps are left out,
  // as a funnel step can only be used once.
  useEffect(() => {
    setJourney((journey) => {
      const isPicked = (step: JourneyStep) =>
        journey.steps.some((s) => journeyStepsEqual(s, step))

      const results = (candidates ?? []).filter(({ step }) => !isPicked(step))
      const typed = typedPageStep(journey.activeFilter)

      const offerTyped =
        typed !== null &&
        !isPicked(typed) &&
        !results.some(({ step }) => journeyStepsEqual(step, typed))

      return {
        ...journey,
        activeResults: offerTyped
          ? [{ step: typed, visitors: 0 }, ...results]
          : results
      }
    })
  }, [candidates, journey.steps, journey.activeFilter])

  useEffect(() => {
    const steps = journey.steps

    if (steps.length < 2) {
      setJourney((journey) => ({ ...journey, funnel: [] }))
      setPreviewError(null)
      setPreviewLoading(false)
      return
    }

    let cancelled = false
    setPreviewLoading(true)

    const timeout = window.setTimeout(() => {
      api
        .post(
          url.apiPath(site, '/funnels/preview'),
          dashboardStateForFunnel(dashboardState),
          {
            steps: steps.map(journeyStepToFunnelStep),
            funnel_type: funnelType
          }
        )
        .then((response: FunnelResponse) => {
          if (cancelled) return
          setPreviewError(null)
          setJourney((journey) =>
            journey.steps === steps
              ? {
                  ...journey,
                  funnel: toFunnelSteps(steps, response),
                  provisional: {}
                }
              : journey
          )
        })
        .catch((error) => {
          if (cancelled) return
          if (isRateLimitedError(error)) setRateLimited(true)
          setPreviewError(errorMessage(error))
          setJourney((journey) => ({ ...journey, funnel: [] }))
        })
        .finally(() => {
          if (!cancelled) setPreviewLoading(false)
        })
    }, PREVIEW_DEBOUNCE_MS)

    return () => {
      cancelled = true
      window.clearTimeout(timeout)
    }
  }, [site, dashboardState, journey.steps, funnelType, retryCount])

  return {
    journey,
    activeLoading,
    previewLoading,
    previewError,
    rateLimited,
    candidatesFailed,
    layoutKey,
    selectStep,
    setActiveFilter,
    retry
  }
}
