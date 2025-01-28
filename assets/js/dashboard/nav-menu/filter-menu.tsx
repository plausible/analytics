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
  const site = useSiteContext()
  const columns = useMemo(() => getFilterListItems(site), [site])
  const ref = useRef<HTMLDivElement>(null)
  return (
    <Popover
      className="shrink-0 md:relative"
      ref={ref}
      data-no-clear-filters-on-escape={true}
    >
      {({ close }) => (
        <>
          <Keybind
            keyboardKey="Escape"
            type="keyup"
            handler={(event) => {
              // ;(event as unknown as Record<string, unknown>).hi = true
              event.stopPropagation()
              event.preventDefault()
              // console.log(`Inner ${open}`, event)
              // if (open) {
              //   handler()
              // }
              // // return true
            }}
            target={ref.current}
            shouldIgnoreWhen={[isModifierPressed, isTyping]}
          />

          <Popover.Button
            className={classNames(
              'flex items-center gap-1',
              'h-9 px-3',
              'rounded text-sm leading-tight',
              'text-gray-500 hover:text-gray-800 hover:bg-gray-200 dark:hover:text-gray-200 dark:hover:bg-gray-900'
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
              <StopEscapePropagation
                // open={open}
                target={ref.current}
                // handler={close}
              />
              {columns.map((filterGroups, index) => (
                <div key={index} className="flex flex-col w-1/2">
                  {filterGroups.map(({ title, modals }) => (
                    <div key={title}>
                      <div className="pb-1 px-4 pt-2 text-xs font-bold uppercase text-indigo-500 dark:text-indigo-400">
                        {title}
                      </div>
                      {modals
                        .filter((m) => !!m)
                        .map((modalKey) => (
                          <AppNavigationLink
                            className={classNames(
                              'flex',
                              'px-4 py-2 text-sm leading-tight hover:bg-gray-100 hover:text-gray-900 dark:hover:bg-gray-900 dark:hover:text-gray-100',
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

const StopEscapePropagation = ({
  // open,
  // handler,
  target
}: {
  // open: boolean
  // handler: () => void
  target: HTMLDivElement | null
}) => {
  // useEffect(() => {}, [])
  // return null
  return (
    <Keybind
      keyboardKey="Escape"
      type="keyup"
      handler={(event) => {
        // ;(event as unknown as Record<string, unknown>).hi = true
        event.stopPropagation()
        event.preventDefault()
        // console.log(`Inner ${open}`, event)
        // if (open) {
        //   handler()
        // }
        // // return true
      }}
      target={target}
      shouldIgnoreWhen={[isModifierPressed, isTyping]}
    />
  )
}
