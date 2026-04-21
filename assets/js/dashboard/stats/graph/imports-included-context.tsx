import React, { createContext, useContext, useMemo, useState } from 'react'
import { NoticeProps } from '../../components/notice'
import { useGraphIntervalContext } from './graph-interval-context'
import { useDashboardStateContext } from '../../dashboard-state-context'

type ImportsIncludedInput = {
  switchVisible: boolean
  switchDisabled: boolean
} | null

export type ImportsIncludedContextValue =
  | { status: 'loading' }
  | { status: 'hidden' }
  | {
      status: 'visible'
      disabled: boolean
      intervalUnsupportedNotice: NoticeProps | null
    }

type ImportsIncludedContextType = {
  value: ImportsIncludedContextValue
  setInput: (input: ImportsIncludedInput) => void
}

const ImportsIncludedContext = createContext<ImportsIncludedContextType | null>(
  null
)

export function ImportsIncludedProvider({
  children
}: {
  children: React.ReactNode
}) {
  const [input, setInput] = useState<ImportsIncludedInput>(null)
  const { selectedInterval } = useGraphIntervalContext()
  const { dashboardState } = useDashboardStateContext()

  const value: ImportsIncludedContextValue = useMemo(() => {
    if (input === null) {
      return { status: 'loading' }
    }
    if (!input.switchVisible) {
      return { status: 'hidden' }
    }
    const intervalUnsupportedNotice =
      ['hour', 'minute'].includes(selectedInterval) &&
      dashboardState.with_imported
        ? {
            title: 'Imported data not shown in graph',
            description:
              'Available as daily totals only. Switch to a daily view to include it.'
          }
        : null
    return {
      status: 'visible',
      disabled: input.switchDisabled,
      intervalUnsupportedNotice
    }
  }, [input, selectedInterval, dashboardState.with_imported])

  return (
    <ImportsIncludedContext.Provider value={{ value, setInput }}>
      {children}
    </ImportsIncludedContext.Provider>
  )
}

export const useImportsIncludedContext = (): ImportsIncludedContextValue =>
  useContext(ImportsIncludedContext)!.value

export const useSetImportsIncluded = () =>
  useContext(ImportsIncludedContext)!.setInput
