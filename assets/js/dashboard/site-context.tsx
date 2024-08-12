/* @format */
import React, { createContext, ReactNode, useContext } from 'react'

export function parseSiteFromDataset(dataset: Record<string, string>) {
  const site = {
    domain: dataset.domain,
    offset: dataset.offset,
    hasGoals: dataset.hasGoals === 'true',
    hasProps: dataset.hasProps === 'true',
    funnelsAvailable: dataset.funnelsAvailable === 'true',
    propsAvailable: dataset.propsAvailable === 'true',
    conversionsOptedOut: dataset.conversionsOptedOut === 'true',
    funnelsOptedOut: dataset.funnelsOptedOut === 'true',
    propsOptedOut: dataset.propsOptedOut === 'true',
    revenueGoals: JSON.parse(dataset.revenueGoals),
    funnels: JSON.parse(dataset.funnels),
    statsBegin: dataset.statsBegin,
    nativeStatsBegin: dataset.nativeStatsBegin,
    embedded: dataset.embedded,
    background: dataset.background,
    isDbip: dataset.isDbip === 'true',
    flags: JSON.parse(dataset.flags),
    validIntervalsByPeriod: JSON.parse(dataset.validIntervalsByPeriod),
    shared: !!dataset.sharedLinkAuth
  }
  return site
}

const siteContextDefaultValue = {
  domain: '',
  offset: '0',
  hasGoals: false,
  hasProps: false,
  funnelsAvailable: false,
  propsAvailable: false,
  conversionsOptedOut: false,
  funnelsOptedOut: false,
  propsOptedOut: false,
  revenueGoals: [] as { event_name: string; currency: 'USD' }[],
  funnels: [] as { id: number; name: string; steps_count: number }[],
  statsBegin: '',
  nativeStatsBegin: '',
  embedded: '',
  background: '',
  isDbip: false,
  flags: {},
  validIntervalsByPeriod: {} as Record<string, Array<string>>,
  shared: false
}

export type PlausibleSite = typeof siteContextDefaultValue

const SiteContext = createContext(siteContextDefaultValue)

export const useSiteContext = () => {
  return useContext(SiteContext)
}

const SiteContextProvider = ({
  site,
  children
}: {
  site: PlausibleSite
  children: ReactNode
}) => {
  return <SiteContext.Provider value={site}>{children}</SiteContext.Provider>
}

export default SiteContextProvider
