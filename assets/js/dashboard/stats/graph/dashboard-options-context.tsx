import React, { createContext, useContext, useState } from 'react'
import { NoticeProps } from '../../components/notice'
import { Interval } from './intervals'

export type DashboardOptionsContextValue = {
  selectedInterval: Interval
  onIntervalClick: (interval: Interval) => void
  availableIntervals: Interval[]
  isRealtime: boolean
  importedSwitchVisible: boolean
  importedIntervalUnsupportedNotice: NoticeProps | null
  importedSwitchDisabled: boolean
}

type DashboardOptionsContextType = {
  options: DashboardOptionsContextValue | null
  setOptions: (v: DashboardOptionsContextValue | null) => void
}

const DashboardOptionsContext =
  createContext<DashboardOptionsContextType | null>(null)

export function DashboardOptionsProvider({
  children
}: {
  children: React.ReactNode
}) {
  const [options, setOptions] = useState<DashboardOptionsContextValue | null>(
    null
  )
  return (
    <DashboardOptionsContext.Provider value={{ options, setOptions }}>
      {children}
    </DashboardOptionsContext.Provider>
  )
}

export const useDashboardOptionsContext = () =>
  useContext(DashboardOptionsContext)?.options ?? null

export const useSetDashboardOptions = () =>
  useContext(DashboardOptionsContext)!.setOptions
