/* @format */
import React from 'react'
import { NavigateKeybind } from './keybinding'
import { useSegmentExpandedContext } from './segments/segment-expanded-context'

const ClearFiltersKeybind = () => (
  <NavigateKeybind
    keyboardKey="Escape"
    type="keyup"
    navigateProps={{
      search: (search) =>
        search.filters || search.labels
          ? {
              ...search,
              filters: null,
              labels: null,
              keybindHint: 'Escape'
            }
          : search
    }}
  />
)

export function DashboardKeybinds() {
  const { modal } = useSegmentExpandedContext()
  return modal === null && <ClearFiltersKeybind />
}
