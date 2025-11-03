import React, { useMemo, useRef } from 'react'
import {
  FILTER_MODAL_TO_FILTER_GROUP,
  formatFilterGroup
} from '../util/filters'
import { PlausibleSite, useSiteContext } from '../site-context'
import { filterRoute } from '../router'
import { Popover, Transition } from '@headlessui/react'
import { popover, BlurMenuButtonOnEscape } from '../components/popover'
import classNames from 'classnames'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import { SearchableSegmentsSection } from './segments/searchable-segments-section'
import { MenuSeparator } from './nav-menu-components'

const FilterIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    className={className}
    fill="none"
  >
    <path
      d="M6 12h12M2 5h20M10 19h4"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
)

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
  const panelRef = useRef<HTMLDivElement>(null)

  return (
    <>
      <BlurMenuButtonOnEscape targetRef={buttonRef} />
      <Popover.Button
        ref={buttonRef}
        className={classNames(
          popover.toggleButton.classNames.rounded,
          popover.toggleButton.classNames.ghost,
          'justify-center gap-2'
        )}
      >
        <FilterIcon className="block size-4 text-gray-500" />
        <span className={popover.toggleButton.classNames.truncatedText}>
          Filter
        </span>
      </Popover.Button>
      <Transition
        as="div"
        {...popover.transition.props}
        className={classNames(
          popover.transition.classNames.fullwidth,
          'mt-2 md:left-auto md:w-72 md:origin-top-right'
        )}
      >
        <Popover.Panel
          ref={panelRef}
          className={classNames(popover.panel.classNames.roundedSheet)}
          data-testid="filtermenu"
        >
          <div className="flex flex-col max-h-[420px] overflow-y-auto overscroll-contain">
            {columns
              .flat()
              .map(({ title, modals }) => (
                <React.Fragment key={title}>
                  <div className="pb-0.5">
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
                  <MenuSeparator />
                </React.Fragment>
              ))}
            <SearchableSegmentsSection
              closeList={closeDropdown}
              tooltipContainerRef={panelRef}
            />
          </div>
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
  'text-xs pb-1 px-4 pt-2 font-semibold uppercase text-gray-400 dark:text-indigo-400'
