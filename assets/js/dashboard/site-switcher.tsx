/**
 * @prettier
 */
import React, { useRef } from 'react'
import { Popover, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import { Cog8ToothIcon, ArrowLeftIcon } from '@heroicons/react/24/outline'
import classNames from 'classnames'
import { isModifierPressed, isTyping, Keybind, KeybindHint } from './keybinding'
import { popover, BlurMenuButtonOnEscape } from './components/popover'
import { useQuery } from '@tanstack/react-query'
import { Role, useUserContext } from './user-context'
import { PlausibleSite, useSiteContext } from './site-context'
import { MenuSeparator } from './nav-menu/nav-menu-components'
import { useMatch } from 'react-router-dom'
import { rootRoute } from './router'
import { get } from './api'
import { ErrorPanel } from './components/error-panel'
import { useRoutelessModalsContext } from './navigation/routeless-modals-context'

const Favicon = ({
  domain,
  className
}: {
  domain: string
  className?: string
}) => (
  <img
    aria-hidden="true"
    alt=""
    src={`/favicon/sources/${encodeURIComponent(domain)}`}
    onError={(e) => {
      const target = e.target as HTMLImageElement
      target.onerror = null
      target.src = '/favicon/sources/placeholder'
    }}
    referrerPolicy="no-referrer"
    className={className}
  />
)

const GlobeIcon = ({ className }: { className?: string }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
    className={className}
  >
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="M22 12H2M12 22c5.714-5.442 5.714-14.558 0-20M12 22C6.286 16.558 6.286 7.442 12 2"
    />
    <path
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.5"
      d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10Z"
    />
  </svg>
)

const menuItemClassName = classNames(
  popover.items.classNames.navigationLink,
  popover.items.classNames.selectedOption,
  popover.items.classNames.hoverLink
)

const buttonLinkClassName = classNames(
  'flex-1 flex items-center justify-center',
  'my-1 mx-1',
  'border border-gray-300 dark:border-gray-700',
  'px-3 py-2 text-sm font-medium rounded-md',
  'bg-white text-gray-700 dark:text-gray-300 dark:bg-gray-700',
  'transition-all duration-200',
  'hover:text-gray-900 hover:border-gray-400/70 dark:hover:bg-gray-600 dark:hover:border-gray-600 dark:hover:text-white'
)

const getSwitchToSiteURL = (
  currentSite: PlausibleSite,
  site: { domain: string }
): string | null => {
  // Prevents reloading the page when the current site is selected
  if (currentSite.domain === site.domain) {
    return null
  }
  return `/${encodeURIComponent(site.domain)}`
}

export const SiteSwitcher = () => {
  const dashboardRouteMatch = useMatch(rootRoute.path)
  const { modal } = useRoutelessModalsContext()
  const user = useUserContext()
  const currentSite = useSiteContext()
  const buttonRef = useRef<HTMLButtonElement>(null)
  const sitesQuery = useQuery({
    enabled: user.loggedIn,
    queryKey: ['sites'],
    queryFn: async (): Promise<{ data: Array<{ domain: string }> }> => {
      const response = await get('/api/sites')
      return response
    },
    placeholderData: (previousData) => previousData
  })

  const sitesInDropdown = user.loggedIn
    ? sitesQuery.data?.data
    : // show only current site in dropdown when viewing public / embedded dashboard
      [{ domain: currentSite.domain }]

  const canSeeSiteSettings: boolean =
    user.loggedIn &&
    [Role.owner, Role.admin, Role.editor, 'super_admin'].includes(user.role)

  const canSeeViewAllSites: boolean = user.loggedIn

  return (
    <Popover className="md:relative">
      {({ close: closePopover }) => (
        <>
          {!!dashboardRouteMatch &&
            !modal &&
            sitesQuery.data?.data.slice(0, 8).map(({ domain }, index) => (
              <Keybind
                key={domain}
                keyboardKey={`${index + 1}`}
                type="keydown"
                handler={() => {
                  const url = getSwitchToSiteURL(currentSite, { domain })
                  if (!url) {
                    closePopover()
                  } else {
                    closePopover()
                    window.location.assign(url)
                  }
                }}
                shouldIgnoreWhen={[isModifierPressed, isTyping]}
                targetRef="document"
              />
            ))}

          {!!dashboardRouteMatch &&
            !modal &&
            user.team?.hasConsolidatedView && 
            user.team.identifier &&

            <Keybind
              key={user.team.identifier}
              keyboardKey="0"
              type="keydown"
              handler={() => {
                const url = getSwitchToSiteURL(currentSite, { domain: user.team.identifier! })
                if (!url) {
                  closePopover()
                } else {
                  closePopover()
                  window.location.assign(url)
                }
              }}
              shouldIgnoreWhen={[isModifierPressed, isTyping]}
              targetRef="document"
            />
          }

          <BlurMenuButtonOnEscape targetRef={buttonRef} />
          <Popover.Button
            ref={buttonRef}
            className={classNames(
              'flex items-center rounded h-9 leading-5 font-bold dark:text-gray-100',
              'hover:bg-gray-100 dark:hover:bg-gray-800'
            )}
            title={currentSite.domain}
          >
            {currentSite.isConsolidatedView ? (
              <GlobeIcon className="size-4 block mx-1 h-4 w-4 text-indigo-600 dark:text-white" />
            ) : (
              <Favicon
                domain={currentSite.domain}
                className="block h-4 w-4 mx-1"
              />
            )}
            <span className={'truncate hidden sm:block sm:mr-1 lg:mr-0'}>
              {currentSite.isConsolidatedView ? "All sites" : currentSite.domain}
            </span>
            <ChevronDownIcon className="hidden lg:block h-5 w-5 ml-2 dark:text-gray-100" />
          </Popover.Button>
          <Transition
            as="div"
            {...popover.transition.props}
            className={classNames(
              popover.transition.classNames.fullwidth,
              'mt-2 md:w-80 md:right-auto md:origin-top-left'
            )}
          >
            <Popover.Panel
              data-testid="sitemenu"
              className={classNames(popover.panel.classNames.roundedSheet)}
            >
              <div className="flex">
                {canSeeViewAllSites && (
                  <a className={buttonLinkClassName} href={`/sites`}>
                    <ArrowLeftIcon className="size-4 mr-1.5" />
                    Back to sites
                  </a>
                )}
                {canSeeSiteSettings && (
                  <a
                    className={buttonLinkClassName}
                    href={`/${encodeURIComponent(currentSite.domain)}/settings/general`}
                  >
                    <Cog8ToothIcon className="size-4 mr-1.5" />
                    Site settings
                  </a>
                )}
              </div>
              {(canSeeSiteSettings || canSeeViewAllSites) && <MenuSeparator />}
              {sitesQuery.isLoading && (
                <div className="px-3 py-2">
                  <div className="loading sm">
                    <div />
                  </div>
                </div>
              )}
              {sitesQuery.isError && (
                <div className="px-3 py-2">
                  <ErrorPanel
                    errorMessage={'Error loading sites'}
                    onClose={sitesQuery.refetch}
                  />
                </div>
              )}
              {user.team.hasConsolidatedView && user.team.identifier && <a
                data-selected={currentSite.isConsolidatedView}
                className={menuItemClassName}
                href={getSwitchToSiteURL(currentSite, { domain: user.team.identifier }) ?? '#'}
                onClick={() => closePopover()}
              >
                <GlobeIcon className="size-4 block mr-2 text-indigo-600 dark:text-white" />
                <span className="truncate mr-auto">All sites</span>
                <KeybindHint>0</KeybindHint>
              </a>}
              {!!sitesInDropdown &&
                sitesInDropdown.map(({ domain }, index) => (
                  <a
                    data-selected={currentSite.domain === domain}
                    key={domain}
                    className={menuItemClassName}
                    href={getSwitchToSiteURL(currentSite, { domain }) ?? '#'}
                    onClick={
                      currentSite.domain === domain
                        ? () => closePopover()
                        : () => {}
                    }
                  >
                    <Favicon domain={domain} className="h-4 w-4 block mr-2" />
                    <span className="truncate mr-auto">{domain}</span>
                    {sitesInDropdown.length > 1 && (
                      <KeybindHint>{index + 1}</KeybindHint>
                    )}
                  </a>
                ))}
            </Popover.Panel>
          </Transition>
        </>
      )}
    </Popover>
  )
}
