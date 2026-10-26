import {
  chronologicalSteps,
  draftInvalidReason,
  journeyStepToFunnelStep,
  savedStepToJourneyStep
} from './funnel-draft'
import { journeyStepsEqual, JourneyStep } from './journey'
import { parseFunnelBuildTarget } from '../../funnels-context'
import { typedPageStep } from './funnel-builder-state'

const LIMITS = {
  minSteps: 2,
  maxSteps: 8,
  journeyEndEvent: '__journey_end__'
}

function page(pathname: string, extra: Partial<JourneyStep> = {}): JourneyStep {
  return {
    label: pathname,
    name: 'pageview',
    pathname,
    includes_subpaths: false,
    subpaths_count: 0,
    is_goal: false,
    ...extra
  }
}

function event(name: string, extra: Partial<JourneyStep> = {}): JourneyStep {
  return { ...page(''), label: name, name, ...extra }
}

describe('journeyStepToFunnelStep', () => {
  it('references goals by id', () => {
    expect(
      journeyStepToFunnelStep(page('/checkout', { is_goal: true, goal_id: 5 }))
    ).toEqual({ goal_id: 5 })
  })

  it('maps pages and grouped pages to dynamic page steps', () => {
    expect(journeyStepToFunnelStep(page('/blog'))).toEqual({
      page_path: '/blog'
    })
    expect(
      journeyStepToFunnelStep(
        page('/blog', { includes_subpaths: true, subpaths_count: 4 })
      )
    ).toEqual({ page_path: '/blog*' })
  })

  it('maps custom events to dynamic event steps', () => {
    expect(journeyStepToFunnelStep(event('Signup'))).toEqual({
      event_name: 'Signup'
    })
  })

  it('round-trips steps of a saved funnel intact', () => {
    const dynamicScroll = savedStepToJourneyStep({
      goal_id: null,
      goal_kind: null,
      label: 'Visit /pricing',
      event_name: null,
      page_path: '/pricing',
      scroll_threshold: 50,
      custom_props: {},
      currency: null
    })

    expect(dynamicScroll).toMatchObject({
      name: 'pageview',
      pathname: '/pricing',
      is_goal: false
    })
    expect(journeyStepToFunnelStep(dynamicScroll)).toEqual({
      page_path: '/pricing',
      scroll_threshold: 50,
      custom_props: {},
      currency: null
    })

    const goal = savedStepToJourneyStep({
      goal_id: 3,
      goal_kind: 'revenue',
      label: 'Purchase',
      event_name: 'Purchase',
      page_path: null,
      scroll_threshold: -1,
      custom_props: {},
      currency: 'USD'
    })

    expect(goal).toMatchObject({ is_goal: true, goal_id: 3, name: 'Purchase' })
    expect(journeyStepToFunnelStep(goal)).toEqual({ goal_id: 3 })
  })
})

describe('chronologicalSteps', () => {
  it('reverses journeys explored backwards from the end point', () => {
    const steps = [page('/thanks'), page('/checkout'), page('/')]

    expect(
      chronologicalSteps(steps, 'backward').map((s) => s.pathname)
    ).toEqual(['/', '/checkout', '/thanks'])
    expect(chronologicalSteps(steps, 'forward')).toBe(steps)
  })
})

describe('draftInvalidReason', () => {
  it('accepts valid steps', () => {
    expect(draftInvalidReason([page('/'), event('Signup')], LIMITS)).toBeNull()
  })

  it('requires the step count to be within limits', () => {
    expect(draftInvalidReason([page('/')], LIMITS)).toMatch(/at least 2/)
    expect(
      draftInvalidReason(
        Array.from({ length: 9 }, (_, i) => page(`/${i}`)),
        LIMITS
      )
    ).toMatch(/at most 8/)
  })

  it('rejects the journey end', () => {
    expect(
      draftInvalidReason([page('/'), event('__journey_end__')], LIMITS)
    ).toMatch(/end of a journey/)
  })

  it('rejects repeated steps', () => {
    expect(
      draftInvalidReason([page('/'), event('Signup'), page('/')], LIMITS)
    ).toMatch(/only be used once/)
  })
})

describe('journeyStepsEqual', () => {
  it('compares pages and events by name and pathname', () => {
    expect(journeyStepsEqual(page('/a'), page('/a'))).toBe(true)
    expect(journeyStepsEqual(page('/a'), page('/b'))).toBe(false)
    expect(
      journeyStepsEqual(page('/a'), page('/a', { includes_subpaths: true }))
    ).toBe(false)
  })

  it('compares goals by id', () => {
    const scrollGoal = page('/a', { is_goal: true, goal_id: 1 })
    const pageGoal = page('/a', { is_goal: true, goal_id: 2 })

    expect(journeyStepsEqual(scrollGoal, { ...scrollGoal, label: 'x' })).toBe(
      true
    )
    expect(journeyStepsEqual(scrollGoal, pageGoal)).toBe(false)
    expect(journeyStepsEqual(scrollGoal, page('/a'))).toBe(false)
  })
})

describe('parseFunnelBuildTarget', () => {
  it('parses new and funnel ids', () => {
    expect(parseFunnelBuildTarget('new')).toBe('new')
    expect(parseFunnelBuildTarget('12')).toBe(12)
    expect(parseFunnelBuildTarget(12)).toBe(12)
  })

  it('ignores anything else', () => {
    expect(parseFunnelBuildTarget(undefined)).toBeNull()
    expect(parseFunnelBuildTarget('abc')).toBeNull()
    expect(parseFunnelBuildTarget('0')).toBeNull()
    expect(parseFunnelBuildTarget(true)).toBeNull()
  })
})

describe('typedPageStep', () => {
  it('turns a typed path into a page step', () => {
    expect(typedPageStep(' /login ')).toMatchObject({
      name: 'pageview',
      pathname: '/login',
      label: '/login',
      is_goal: false
    })
    expect(journeyStepToFunnelStep(typedPageStep('/blog/**')!)).toEqual({
      page_path: '/blog/**'
    })
  })

  it('ignores anything that is not a path', () => {
    expect(typedPageStep('')).toBeNull()
    expect(typedPageStep('login')).toBeNull()
    expect(typedPageStep('/log in')).toBeNull()
  })
})
