/** @format */

import React, { useMemo, useRef, useState } from 'react'
import {
  DropdownLinkGroup,
  DropdownMenuWrapper,
  DropdownNavigationLink,
  DropdownSubtitle,
  ToggleDropdownButton
} from '../components/dropdown'
import {
  FILTER_MODAL_TO_FILTER_GROUP,
  formatFilterGroup
} from '../util/filters'
import { PlausibleSite, useSiteContext } from '../site-context'
import { filterRoute } from '../router'
import { useOnClickOutside } from '../util/use-on-click-outside'
import { PlusIcon } from '@heroicons/react/20/solid'
import { isModifierPressed, isTyping, Keybind } from '../keybinding'

export function getFilterListItems({
  propsAvailable
}: Pick<PlausibleSite, 'propsAvailable'>): Array<
  Array<{
    title: string
    modals: Array<false | keyof typeof FILTER_MODAL_TO_FILTER_GROUP>
  }>
> {
  return [
    [
      {
        title: 'URL',
        modals: ['page', 'hostname']
      },
      {
        title: 'Acquisition',
        modals: ['source', 'utm']
      }
    ],
    [
      {
        title: 'Device',
        modals: ['location', 'screen', 'browser', 'os']
      },
      {
        title: 'Behaviour',
        modals: ['goal', !!propsAvailable && 'props']
      }
    ]
  ]
}

export const FilterMenu = () => {
  const dropdownRef = useRef<HTMLDivElement>(null)
  const [opened, setOpened] = useState(false)
  const site = useSiteContext()
  const columns = useMemo(() => getFilterListItems(site), [site])

  useOnClickOutside({
    ref: dropdownRef,
    active: opened,
    handler: () => setOpened(false)
  })

  return (
    <ToggleDropdownButton
      ref={dropdownRef}
      variant="ghost"
      className="shrink-0 md:relative"
      dropdownContainerProps={{
        ['aria-controls']: 'filter-menu',
        ['aria-expanded']: opened
      }}
      onClick={() => setOpened((opened) => !opened)}
      currentOption={
        <div className="flex items-center gap-1 ">
          <PlusIcon className="block h-4 w-4" />
          Add filter
        </div>
      }
    >
      {opened && (
        <DropdownMenuWrapper id="filter-menu" className="md:left-auto md:w-80">
          <Keybind
            keyboardKey="Escape"
            shouldIgnoreWhen={[isModifierPressed, isTyping]}
            type="keyup"
            handler={(event) => {
              event.stopPropagation()
              setOpened(false)
            }}
            target={dropdownRef.current}
          />

          <DropdownLinkGroup className="flex flex-row">
            {columns.map((filterGroups, index) => (
              <div key={index} className="flex flex-col w-1/2">
                {filterGroups.map(({ title, modals }) => (
                  <div key={title}>
                    <DropdownSubtitle className="pb-1">
                      {title}
                    </DropdownSubtitle>
                    {modals
                      .filter((m) => !!m)
                      .map((modalKey) => (
                        <DropdownNavigationLink
                          className={'text-xs'}
                          onClick={() => setOpened(false)}
                          active={false}
                          key={modalKey}
                          path={filterRoute.path}
                          params={{ field: modalKey }}
                          search={(search) => search}
                        >
                          {formatFilterGroup(modalKey)}
                        </DropdownNavigationLink>
                      ))}
                  </div>
                ))}
              </div>
            ))}
          </DropdownLinkGroup>
        </DropdownMenuWrapper>
      )}
    </ToggleDropdownButton>
  )
}
