/* @format */
import React from 'react'
import { NavigateKeybind } from './keybinding'
import { useRoutelessModalsContext } from './navigation/routeless-modals-context'

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
  const { modal } = useRoutelessModalsContext()
  return modal === null && <ClearFiltersKeybind />
}
