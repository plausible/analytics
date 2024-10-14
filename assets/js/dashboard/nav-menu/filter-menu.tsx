/** @format */

import React, { useRef, useState } from 'react'
import {
  DropdownLinkGroup,
  DropdownMenuWrapper,
  DropdownNavigationLink,
  ToggleDropdownButton
} from '../components/dropdown'
import { MagnifyingGlassIcon } from '@heroicons/react/20/solid'
import {
  FILTER_MODAL_TO_FILTER_GROUP,
  formatFilterGroup
} from '../util/filters'
import { useSiteContext } from '../site-context'
import { filterRoute } from '../router'
import { useOnClickOutside } from '../util/use-on-click-outside'

export const FilterMenu = () => {
  const dropdownRef = useRef<HTMLDivElement>(null)
  const [opened, setOpened] = useState(false)
  const site = useSiteContext()
  const modalKeys = site.propsAvailable
    ? Object.keys(FILTER_MODAL_TO_FILTER_GROUP)
    : Object.keys(FILTER_MODAL_TO_FILTER_GROUP).filter((k) => k !== 'props')

  useOnClickOutside({
    ref: dropdownRef,
    active: opened,
    handler: () => setOpened(false)
  })
  return (
    <ToggleDropdownButton
      ref={dropdownRef}
      variant="ghost"
      className="ml-auto md:relative"
      dropdownContainerProps={{
        ['aria-controls']: 'filter-menu',
        ['aria-expanded']: opened
      }}
      onClick={() => setOpened((opened) => !opened)}
      currentOption={
        <span className="flex items-center">
          <MagnifyingGlassIcon className="block h-4 w-4" />
          <span className="block ml-1">Filter</span>
        </span>
      }
    >
      {opened && (
        <DropdownMenuWrapper id="filter-menu">
          <DropdownLinkGroup>
            {modalKeys.map((modalKey) => (
              <DropdownNavigationLink
                active={false}
                key={modalKey}
                path={filterRoute.path}
                params={{ field: modalKey }}
                search={(search) => search}
              >
                {formatFilterGroup(modalKey)}
              </DropdownNavigationLink>
            ))}
          </DropdownLinkGroup>
        </DropdownMenuWrapper>
      )}
    </ToggleDropdownButton>
  )
}
