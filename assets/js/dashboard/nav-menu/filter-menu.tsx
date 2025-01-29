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
  const site = useSiteContext()
  const columns = useMemo(() => getFilterListItems(site), [site])
  const buttonRef = useRef<HTMLButtonElement>(null)
  return (
    <Popover
      className="shrink-0 md:relative"
      data-no-clear-filters-on-escape={true}
    >
      {({ close }) => (
        <>
          <BlurMenuButtonOnEscape targetRef={buttonRef} />
          <Popover.Button
            ref={buttonRef}
            className={classNames(
              popover.toggleButton.classNames.rounded,
              popover.toggleButton.classNames.ghost,
              'justify-center gap-1 px-3'
            )}
          >
            <PlusIcon className="block h-4 w-4" />
            <span className="truncate block font-medium">Add filter</span>
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
              className={classNames(
                popover.panel.classNames.roundedSheet,
                'flex'
              )}
            >
              {columns.map((filterGroups, index) => (
                <div key={index} className="flex flex-col w-1/2">
                  {filterGroups.map(({ title, modals }) => (
                    <div key={title}>
                      <div className="text-xs pb-1 px-4 pt-2 font-bold uppercase text-indigo-500 dark:text-indigo-400">
                        {title}
                      </div>
                      {modals
                        .filter((m) => !!m)
                        .map((modalKey) => (
                          <AppNavigationLink
                            className={classNames(
                              popover.items.classNames.navigationLink,
                              popover.items.classNames.hoverLink,
                              'text-xs'
                            )}
                            onClick={() => close()}
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
            </Popover.Panel>
          </Transition>
        </>
      )}
    </Popover>
  )
}
