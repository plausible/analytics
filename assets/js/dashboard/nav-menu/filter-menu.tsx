/** @format */

import React, { useMemo, useRef } from 'react'
import {
  FILTER_MODAL_TO_FILTER_GROUP,
  formatFilterGroup
} from '../util/filters'
import { PlausibleSite, useSiteContext } from '../site-context'
import { filterRoute } from '../router'
import { PlusIcon } from '@heroicons/react/20/solid'
import { Popover, Transition } from '@headlessui/react'
import { popover } from '../components/popover'
import classNames from 'classnames'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import { BlurMenuButtonOnEscape } from '../keybinding'
import { SearchableSegmentsSection } from './segments/searchable-segments-section'

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

const FilterMenuItems = ({ closeDropdown }: { closeDropdown: () => void }) => {
  const site = useSiteContext()
  const columns = useMemo(() => getFilterListItems(site), [site])
  const buttonRef = useRef<HTMLButtonElement>(null)

  return (
    <>
      <BlurMenuButtonOnEscape targetRef={buttonRef} />
      <Popover.Button
        ref={buttonRef}
        className={classNames(
          popover.toggleButton.classNames.rounded,
          popover.toggleButton.classNames.shadow,
          'justify-center gap-1 px-3'
        )}
      >
        <PlusIcon className="block h-4 w-4" />
        <span className={popover.toggleButton.classNames.truncatedText}>
          Filter
        </span>
      </Popover.Button>
      <Transition
        {...popover.transition.props}
        className={classNames(
          'mt-2',
          popover.transition.classNames.fullwidth,
          'md:left-auto md:w-80'
        )}
      >
        <Popover.Panel
          className={classNames(popover.panel.classNames.roundedSheet)}
        >
          <div className="flex">
            {columns.map((filterGroups, index) => (
              <div key={index} className="flex flex-col w-1/2">
                {filterGroups.map(({ title, modals }) => (
                  <div key={title}>
                    <div className={titleClassName}>{title}</div>
                    {modals
                      .filter((m) => !!m)
                      .map((modalKey) => (
                        <AppNavigationLink
                          className={classNames(
                            popover.items.classNames.navigationLink,
                            popover.items.classNames.hoverLink
                          )}
                          onClick={() => closeDropdown()}
                          key={modalKey}
                          path={filterRoute.path}
                          params={{ field: modalKey }}
                          search={(s) => s}
                        >
                          {formatFilterGroup(modalKey)}
                        </AppNavigationLink>
                      ))}
                  </div>
                ))}
              </div>
            ))}
          </div>
          <SearchableSegmentsSection closeList={closeDropdown} />
        </Popover.Panel>
      </Transition>
    </>
  )
}

export const FilterMenu = () => (
  <Popover className="shrink-0 md:relative">
    {({ close }) => <FilterMenuItems closeDropdown={close} />}
  </Popover>
)

const titleClassName =
  'text-sm pb-1 px-4 pt-2 font-bold uppercase text-indigo-500 dark:text-indigo-400'
