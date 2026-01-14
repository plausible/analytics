import React, { useCallback, useContext, useState } from 'react'
import { PlausibleSite, useSiteContext } from '../../site-context'
import { UserContextValue, useUserContext } from '../../user-context'

export enum Mode {
  CONVERSIONS = 'conversions',
  PROPS = 'props',
  FUNNELS = 'funnels'
}

export const MODES = {
  [Mode.CONVERSIONS]: {
    title: 'Goal conversions',
    isAvailableKey: null, // always available
    optedOutKey: `${Mode.CONVERSIONS}OptedOut`
  },
  [Mode.PROPS]: {
    title: 'Custom properties',
    isAvailableKey: `${Mode.PROPS}Available`,
    optedOutKey: `${Mode.PROPS}OptedOut`
  },
  [Mode.FUNNELS]: {
    title: 'Funnels',
    isAvailableKey: `${Mode.FUNNELS}Available`,
    optedOutKey: `${Mode.FUNNELS}OptedOut`
  }
} as const

export const getFirstPreferenceFromEnabledModes = (
  preferredModes: Mode[],
  enabledModes: Mode[]
): Mode | null => {
  const defaultPreferenceOrder = [Mode.CONVERSIONS, Mode.PROPS, Mode.FUNNELS]
  for (const mode of [...preferredModes, ...defaultPreferenceOrder]) {
    if (enabledModes.includes(mode)) {
      return mode
    }
  }
  return null
}

function getInitiallyAvailableModes({
  site,
  user
}: {
  site: PlausibleSite
  user: UserContextValue
}): Mode[] {
  return Object.entries(MODES)
    .filter(([_, { isAvailableKey, optedOutKey }]) => {
      const isOptedOut = site[optedOutKey]
      const isAvailable = isAvailableKey ? site[isAvailableKey] : true

      // If the feature is not supported by the site owner's subscription,
      // it only makes sense to display the feature tab to the owner itself
      // as only they can upgrade to make the feature available.
      const callToActionIsMissing = !isAvailable && user.role !== 'owner'
      if (!isOptedOut && !callToActionIsMissing) {
        return true
      }
      return false
    })
    .map(([mode, _]) => mode as Mode)
}

const modesContextDefaultValue = {
  enabledModes: [] as Mode[],
  disableMode: (() => {}) as (mode: Mode) => void
}
const ModesContext = React.createContext(modesContextDefaultValue)
export const useModesContext = () => {
  return useContext(ModesContext)
}

export const ModesContextProvider = ({
  children
}: {
  children: React.ReactNode
}) => {
  const site = useSiteContext()
  const user = useUserContext()
  const [enabledModes, setEnabledModes] = useState(
    getInitiallyAvailableModes({ site, user })
  )

  const disableMode = useCallback((mode: Mode) => {
    setEnabledModes((modes) => modes.filter((m) => m !== mode))
  }, [])

  return (
    <ModesContext.Provider value={{ enabledModes, disableMode }}>
      {children}
    </ModesContext.Provider>
  )
}
