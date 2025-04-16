/**
 * @prettier
 */
import React, { useRef } from 'react'
import {
  Popover,
  PopoverButton,
  PopoverPanel,
  Transition
} from '@headlessui/react'
import { Cog8ToothIcon, ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import {
  BlurMenuButtonOnEscape,
  isModifierPressed,
  isTyping,
  Keybind,
  KeybindHint
} from './keybinding'
import { popover } from './components/popover'
import { useQuery } from '@tanstack/react-query'
import { Role, useUserContext } from './user-context'
import { PlausibleSite, useSiteContext } from './site-context'
import { MenuSeparator } from './nav-menu/nav-menu-components'
import { useMatch } from 'react-router-dom'
import { rootRoute } from './router'
import { get } from './api'
import { ErrorPanel } from './components/error-panel'

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

const menuItemClassName = classNames(
  popover.items.classNames.navigationLink,
  popover.items.classNames.selectedOption,
  popover.items.classNames.hoverLink,
  popover.items.classNames.roundedStartEnd
)

const getSwitchToSiteURL = (
  currentSite: PlausibleSite,
  site: { domain: string }
) => {
  // Prevents reloading the page when the current site is selected
  if (currentSite.domain === site.domain) {
    return '#'
  }
  return `/${encodeURIComponent(site.domain)}`
}

export const SiteSwitcher = () => {
  const dashboardRouteMatch = useMatch(rootRoute.path)
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
      {({ close }) => (
        <>
          {!!dashboardRouteMatch &&
            sitesQuery.data?.data.length &&
            sitesQuery.data.data.slice(0, 8).map(({ domain }, index) => (
              <Keybind
                key={domain}
                keyboardKey={`${index + 1}`}
                type="keydown"
                handler={() => {
                  close()
                  window.location.assign(
                    getSwitchToSiteURL(currentSite, { domain })
                  )
                }}
                shouldIgnoreWhen={[isModifierPressed, isTyping]}
                targetRef="document"
              />
            ))}

          <BlurMenuButtonOnEscape targetRef={buttonRef} />
          <PopoverButton
            ref={buttonRef}
            className={classNames(
              'flex items-center rounded h-9 leading-5 font-bold dark:text-gray-100',
              'hover:bg-gray-100 dark:hover:bg-gray-800'
            )}
            title={currentSite.domain}
          >
            <Favicon
              domain={currentSite.domain}
              className="block h-4 w-4 mx-1"
            />
            <span className={'truncate hidden sm:block sm:mr-1 lg:mr-0'}>
              {currentSite.domain}
            </span>
            <ChevronDownIcon className="hidden lg:block h-5 w-5 ml-2 dark:text-gray-100" />
          </PopoverButton>
          <Transition
            as="div"
            {...popover.transition.props}
            className={classNames(
              'mt-2 md:w-64',
              popover.transition.classNames.fullwidth
            )}
          >
            <PopoverPanel
              data-testid="sitemenu"
              className={classNames(popover.panel.classNames.roundedSheet)}
            >
              {canSeeSiteSettings && (
                <>
                  <a
                    className={menuItemClassName}
                    href={`/${encodeURIComponent(currentSite.domain)}/settings/general`}
                    onClick={() => close()}
                  >
                    <Cog8ToothIcon className="h-4 w-4 block mr-2" />
                    <span className="mr-auto">Site settings</span>
                  </a>
                  <MenuSeparator />
                </>
              )}
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
              {!!sitesInDropdown &&
                sitesInDropdown.map(({ domain }, index) => (
                  <a
                    data-selected={currentSite.domain === domain}
                    key={domain}
                    className={menuItemClassName}
                    href={getSwitchToSiteURL(currentSite, { domain })}
                    onClick={() => close()}
                  >
                    <Favicon domain={domain} className="h-4 w-4 block mr-2" />
                    <span className="truncate mr-auto">{domain}</span>
                    {sitesInDropdown.length > 1 && (
                      <KeybindHint>{index + 1}</KeybindHint>
                    )}
                  </a>
                ))}

              {canSeeViewAllSites && (
                <>
                  <MenuSeparator />
                  <a
                    className={menuItemClassName}
                    href={`/sites`}
                    onClick={() => close()}
                  >
                    View all
                  </a>
                </>
              )}
            </PopoverPanel>
          </Transition>
        </>
      )}
    </Popover>
  )
}
