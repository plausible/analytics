/* @format */
import React from 'react'
import { NavigateKeybind } from './keybinding'

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
  return <ClearFiltersKeybind /> // temp disable
}
