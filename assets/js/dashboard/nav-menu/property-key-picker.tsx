import React from 'react'
import { useDashboardStateContext } from '../dashboard-state-context'
import { useSiteContext } from '../site-context'
import {
  EVENT_PROPS_PREFIX,
  getPropertyKeyFromFilterKey
} from '../util/filters'
import { apiPath } from '../util/url'
import { Combobox, isSameValue } from '../components/combobox'

export const PropertyKeyPicker = ({
  onSelect
}: {
  onSelect: (propKey: string) => void
}) => {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const usedKeys = dashboardState.filters
    .filter(([_operation, key]) => key.startsWith(EVENT_PROPS_PREFIX))
    .map(([_operation, key]) => getPropertyKeyFromFilterKey(key))

  return (
    <Combobox
      request={{ path: apiPath(site, '/suggestions/prop_key') }}
      isDisabled={(option) =>
        usedKeys.some((key) => isSameValue(key, option.value))
      }
      onSelect={(option) => onSelect(String(option.value))}
      label="Properties"
    />
  )
}
