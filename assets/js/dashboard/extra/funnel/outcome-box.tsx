import React, { ReactNode, useLayoutEffect, useRef, useState } from 'react'
import classNames from 'classnames'

import { numberLongFormatter, rateFormatter } from '../../util/number-formatter'
import { StepOutcome, StepValues } from './metrics'

// The outcome box sits at the foot of a funnel bar. By default it is a compact
// pill with the rates only ("→ 55% ↓ 45%"). On hover, focus, or touch it grows
// into a panel that shows the rates and visitor counts in full.
//
// CSS cannot transition to an automatic size, so the box cannot grow to
// fit whichever contents are on show. Both states are therefore measured, and
// their pixel sizes are published as CSS variables on the box. The box then
// animates between those two sizes.

const OUTCOME_INSET_PX = 4

type Outcome = {
  kind: 'continued' | 'droppedOff'
  symbol: string
  rate: string
  detail: string
  count: string
}

function outcome(
  kind: Outcome['kind'],
  symbol: string,
  { rate, visitors }: StepOutcome,
  verb: string
): Outcome {
  const formatted = rateFormatter(rate)

  return {
    kind,
    symbol,
    rate: formatted,
    detail: `${formatted} ${verb}`,
    count: `(${numberLongFormatter(visitors)})`
  }
}

function stepOutcomes(
  values: StepValues,
  entryStep: boolean,
  finalStep: boolean
): Outcome[] {
  const continuedVerb = entryStep
    ? 'entered'
    : finalStep
      ? 'converted'
      : 'continued'

  const outcomes = [
    outcome('continued', finalStep ? '✓' : '→', values.continued, continuedVerb)
  ]

  if (!entryStep) {
    outcomes.push(outcome('droppedOff', '↓', values.droppedOff, 'dropped off'))
  }

  return outcomes
}

function OutcomeText({
  outcome,
  detailed
}: {
  outcome: Outcome
  detailed: boolean
}): ReactNode {
  return (
    <span
      className={classNames(
        'flex items-start gap-1 font-medium',
        outcome.kind === 'droppedOff'
          ? 'text-gray-500 dark:text-gray-400'
          : 'text-gray-900 dark:text-gray-100'
      )}
    >
      <span className="font-semibold">{outcome.symbol}</span>
      <span className="flex flex-wrap gap-x-1">
        <span className="whitespace-nowrap">
          {detailed ? outcome.detail : outcome.rate}
        </span>
        {detailed && <span className="whitespace-nowrap">{outcome.count}</span>}
      </span>
    </span>
  )
}

// Publishes the size of the compact contents and the size of the expanded
// contents on the box, as the CSS variables that its transition reads.
function useOutcomeSize(measureKey: string) {
  const box = useRef<HTMLButtonElement>(null)
  const compact = useRef<HTMLDivElement>(null)
  const expanded = useRef<HTMLDivElement>(null)

  useLayoutEffect(() => {
    const boxElement = box.current
    const compactElement = compact.current
    const expandedElement = expanded.current
    const plot = boxElement?.parentElement

    if (!boxElement || !compactElement || !expandedElement || !plot) {
      return
    }

    const measure = (): void => {
      const expandedAt = (width: string): DOMRect => {
        expandedElement.style.width = width
        return expandedElement.getBoundingClientRect()
      }

      // The detailed contents keep to one line while that fits the column, and
      // wrap to their narrowest form when it does not. Each candidate is
      // measured in the state it will really be in, so the height that comes
      // back already accounts for the extra lines.
      const oneLine = expandedAt('max-content')
      const room = plot.clientWidth - 2 * OUTCOME_INSET_PX
      const grown = oneLine.width <= room ? oneLine : expandedAt('min-content')
      expandedElement.style.width = ''

      const collapsed = compactElement.getBoundingClientRect()

      boxElement.style.setProperty('--outcome-w', `${collapsed.width}px`)
      boxElement.style.setProperty('--outcome-h', `${collapsed.height}px`)
      boxElement.style.setProperty('--outcome-grown-w', `${grown.width}px`)
      boxElement.style.setProperty('--outcome-grown-h', `${grown.height}px`)
    }

    measure()

    // Watching the expanded element would loop, because measure resizes it.
    const observer = new ResizeObserver(measure)
    observer.observe(plot)
    observer.observe(compactElement)

    return () => observer.disconnect()
  }, [measureKey])

  return { box, compact, expanded }
}

export function StepOutcomes({
  values,
  entryStep,
  finalStep,
  previousPeriod
}: {
  values: StepValues
  entryStep: boolean
  finalStep: boolean
  previousPeriod?: boolean
}): ReactNode {
  const [open, setOpen] = useState(false)

  const outcomes = stepOutcomes(values, entryStep, finalStep)
  const label = outcomes
    .map(({ detail, count }) => `${detail} ${count}`)
    .join(', ')

  const accessibleName = previousPeriod ? `Previous period: ${label}` : label

  const { box, compact, expanded } = useOutcomeSize(accessibleName)

  return (
    <button
      ref={box}
      type="button"
      aria-label={accessibleName}
      data-open={open || undefined}
      onClick={() => setOpen((shown) => !shown)}
      style={{ left: OUTCOME_INSET_PX, bottom: OUTCOME_INSET_PX }}
      className={classNames(
        'group/outcome absolute overflow-hidden rounded-md text-left cursor-default bg-white/70 dark:bg-gray-900/60 backdrop-blur-xs',
        'ring-1 ring-gray-900/5 dark:ring-white/10 shadow-xs',
        'w-[var(--outcome-w,max-content)] h-[var(--outcome-h,auto)]',
        'transition-[width,height] duration-200 ease-out',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500/40',
        'group-hover/bar:w-[var(--outcome-grown-w)] group-hover/bar:h-[var(--outcome-grown-h)]',
        'focus-visible:w-[var(--outcome-grown-w)] focus-visible:h-[var(--outcome-grown-h)]',
        'data-open:w-[var(--outcome-grown-w)] data-open:h-[var(--outcome-grown-h)]'
      )}
    >
      <div
        ref={compact}
        aria-hidden="true"
        className="flex items-center gap-1.5 w-max px-1.5 py-0.5 text-xs leading-4 whitespace-nowrap transition-opacity duration-200 starting:opacity-0 group-hover/bar:opacity-0 group-focus-visible/outcome:opacity-0 group-data-open/outcome:opacity-0"
      >
        {outcomes.map((outcome) => (
          <OutcomeText key={outcome.kind} outcome={outcome} detailed={false} />
        ))}
      </div>

      <div
        ref={expanded}
        aria-hidden="true"
        className="absolute top-0 left-0 flex flex-col gap-0.5 w-[var(--outcome-grown-w,max-content)] px-1.5 py-0.5 text-xs leading-4 opacity-0 transition-opacity duration-150 group-hover/bar:opacity-100 group-focus-visible/outcome:opacity-100 group-data-open/outcome:opacity-100"
      >
        {outcomes.map((outcome) => (
          <OutcomeText key={outcome.kind} outcome={outcome} detailed={true} />
        ))}
      </div>
    </button>
  )
}
