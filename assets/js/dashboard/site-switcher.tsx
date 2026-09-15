/**
 * @prettier
 */
import React from 'react'
import classNames from 'classnames'
import { popover } from './components/popover'
import { Favicon } from './components/site-icon'
import { useSiteContext } from './site-context'

export const SiteSwitcherStatic = () => {
  const currentSite = useSiteContext()

  return (
    <div
      data-testid="site-switcher-static"
      className={classNames(
        popover.toggleButton.classNames.rounded,
        'gap-x-1.5 font-medium text-gray-700 dark:text-gray-100'
      )}
      title={currentSite.domain}
    >
      <Favicon domain={currentSite.domain} />
      <span className="truncate hidden sm:block sm:mr-1 lg:mr-0 font-semibold">
        {currentSite.domain}
      </span>
    </div>
  )
}
