import React, { createContext, useContext, useState } from 'react'
import { NoticeProps } from '../../components/notice'

export type DashboardOptionsContextValue = {
  selectedInterval: string
  onIntervalClick: (interval: string) => void
  availableIntervals: string[]
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
