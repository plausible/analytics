/** @format */
import React, { createContext, ReactNode, useContext } from 'react'

export function parseSiteFromDataset(dataset: DOMStringMap): PlausibleSite {
  return {
    domain: dataset.domain!,
    offset: parseInt(dataset.offset!, 10),
    hasGoals: dataset.hasGoals === 'true',
    hasProps: dataset.hasProps === 'true',
    scrollDepthVisible: dataset.scrollDepthVisible === 'true',
    funnelsAvailable: dataset.funnelsAvailable === 'true',
    propsAvailable: dataset.propsAvailable === 'true',
    conversionsOptedOut: dataset.conversionsOptedOut === 'true',
    funnelsOptedOut: dataset.funnelsOptedOut === 'true',
    propsOptedOut: dataset.propsOptedOut === 'true',
    revenueGoals: JSON.parse(dataset.revenueGoals!),
    funnels: JSON.parse(dataset.funnels!),
    statsBegin: dataset.statsBegin!,
    nativeStatsBegin: dataset.nativeStatsBegin!,
    embedded: dataset.embedded === 'true',
    background: dataset.background,
    isDbip: dataset.isDbip === 'true',
    flags: JSON.parse(dataset.flags!),
    validIntervalsByPeriod: JSON.parse(dataset.validIntervalsByPeriod!),
    shared: !!dataset.sharedLinkAuth
  }
}

type FeatureFlags = {
  channels?: boolean
  saved_segments?: boolean
}

const siteContextDefaultValue = {
  domain: '',
  /** offset in seconds from UTC at site load time, @example 7200 */
  offset: 0,
  hasGoals: false,
  hasProps: false,
  scrollDepthVisible: false,
  funnelsAvailable: false,
  propsAvailable: false,
  conversionsOptedOut: false,
  funnelsOptedOut: false,
  propsOptedOut: false,
  revenueGoals: [] as { display_name: string; currency: 'USD' }[],
  funnels: [] as { id: number; name: string; steps_count: number }[],
  /** date in YYYY-MM-DD, @example "2023-01-01" */
  statsBegin: '',
  /** date in YYYY-MM-DD, @example "2023-04-01" */
  nativeStatsBegin: '',
  embedded: false,
  background: undefined as string | undefined,
  isDbip: false,
  flags: {} as FeatureFlags,
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
