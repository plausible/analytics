/** @format */

import React, { useMemo, useRef, useState } from 'react'
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
import { PlausibleSite, useSiteContext } from '../site-context'
import { filterRoute } from '../router'
import { useOnClickOutside } from '../util/use-on-click-outside'
import { SegmentsList } from '../segments/segments-dropdown'

export function getFilterListItems({
  propsAvailable
}: Pick<PlausibleSite, 'propsAvailable'>): {
  modalKey: string
  label: string
}[] {
  const allKeys = Object.keys(FILTER_MODAL_TO_FILTER_GROUP) as Array<
    keyof typeof FILTER_MODAL_TO_FILTER_GROUP
  >
  const keysToOmit: Array<keyof typeof FILTER_MODAL_TO_FILTER_GROUP> =
    propsAvailable ? ['segment'] : ['segment', 'props']
  return allKeys
    .filter((k) => !keysToOmit.includes(k))
    .map((modalKey) => ({ modalKey, label: formatFilterGroup(modalKey) }))
}

export const FilterMenu = () => {
  const dropdownRef = useRef<HTMLDivElement>(null)
  const [opened, setOpened] = useState(false)
  const site = useSiteContext()
  const filterListItems = useMemo(() => getFilterListItems(site), [site])

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
        <DropdownMenuWrapper id="filter-menu" className="md:left-auto md:w-56">
          <SegmentsList closeList={() => setOpened(false)} />
          <DropdownLinkGroup>
            {filterListItems.map(({ modalKey, label }) => (
              <DropdownNavigationLink
                onLinkClick={() => setOpened(false)}
                active={false}
                key={modalKey}
                path={filterRoute.path}
                params={{ field: modalKey }}
                search={(search) => search}
              >
                {label}
              </DropdownNavigationLink>
            ))}
          </DropdownLinkGroup>
        </DropdownMenuWrapper>
      )}
    </ToggleDropdownButton>
  )
}
