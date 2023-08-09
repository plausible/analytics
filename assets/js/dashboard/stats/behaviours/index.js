import React, { Fragment, useState, useEffect } from 'react'
import { Menu, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import * as storage from '../../util/storage'

import GoalConversions, { specialTitleWhenGoalFilter } from './goal-conversions'
import DeprecatedConversions from './deprecated-conversions'
import Properties from './props'
import Funnel from './funnel'
import { FeatureSetupNotice } from '../../components/notice'

const ACTIVE_CLASS = 'inline-block h-5 text-indigo-700 dark:text-indigo-500 font-bold active-prop-heading truncate text-left'
const DEFAULT_CLASS = 'hover:text-indigo-600 cursor-pointer truncate text-left'

export const CONVERSIONS = 'conversions'
export const PROPS = 'props'
export const FUNNELS = 'funnels'

export const sectionTitles = {
  [CONVERSIONS]: 'Goal Conversions',
  [PROPS]: 'Custom Properties',
  [FUNNELS]: 'Funnels'
}

export default function Behaviours(props) {
  const {site, query, currentUserRole} = props
  const adminAccess = ['owner', 'admin', 'super_admin'].includes(currentUserRole)
  const tabKey = `behavioursTab__${site.domain}`
  const funnelKey = `behavioursTabFunnel__${site.domain}`
  const [enabledModes, setEnabledModes] = useState(getEnabledModes())
  const [mode, setMode] = useState(defaultMode())

  const [funnelNames, _setFunnelNames] = useState(site.funnels.map(({ name }) => name))
  const [selectedFunnel, setSelectedFunnel] = useState(storage.getItem(funnelKey))

  useEffect(() => {
    setMode(defaultMode())
  }, [enabledModes])

  function disableMode(mode) {
    setEnabledModes(enabledModes.filter((m) => { return m !== mode }))
  }

  function setFunnel(selectedFunnel) {
    return () => {
      storage.setItem(tabKey, FUNNELS)
      storage.setItem(funnelKey, selectedFunnel)
      setMode(FUNNELS)
      setSelectedFunnel(selectedFunnel)
    }
  }

  function hasFunnels() {
    return site.funnels.length > 0
  }

  function tabFunnelPicker() {
    return <Menu as="div" className="relative inline-block text-left">
      <div>
        <Menu.Button className="inline-flex justify-between focus:outline-none">
          <span className={(mode == FUNNELS) ? ACTIVE_CLASS : DEFAULT_CLASS}>Funnels</span>
          <ChevronDownIcon className="-mr-1 ml-1 h-4 w-4" aria-hidden="true" />
        </Menu.Button>
      </div>

      <Transition
        as={Fragment}
        enter="transition ease-out duration-100"
        enterFrom="transform opacity-0 scale-95"
        enterTo="transform opacity-100 scale-100"
        leave="transition ease-in duration-75"
        leaveFrom="transform opacity-100 scale-100"
        leaveTo="transform opacity-0 scale-95"
      >
        <Menu.Items className="text-left origin-top-right absolute right-0 mt-2 w-56 rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 focus:outline-none z-10">
          <div className="py-1">
            {funnelNames.map((funnelName) => {
              return (
                <Menu.Item key={funnelName}>
                  {({ active }) => (
                    <span
                      onClick={setFunnel(funnelName)}
                      className={classNames(
                        active ? 'bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-200 cursor-pointer' : 'text-gray-700 dark:text-gray-200',
                        'block px-4 py-2 text-sm',
                        (mode === FUNNELS && selectedFunnel === funnelName) ? 'font-bold text-gray-500' : ''
                      )}
                    >
                      {funnelName}
                    </span>
                  )}
                </Menu.Item>
              )
            })}
          </div>
        </Menu.Items>
      </Transition>
    </Menu>
  }

  function tabSwitcher(toMode, displayName) {
    const className = classNames({ [ACTIVE_CLASS]: mode == toMode, [DEFAULT_CLASS]: mode !== toMode })
    const setTab = () => {
      storage.setItem(tabKey, toMode)
      setMode(toMode)
    }

    return (
      <div className={className} onClick={setTab}>
        {displayName}
      </div>
    )
  }

  function tabs() {
    return (
      <div className="flex text-xs font-medium text-gray-500 dark:text-gray-400 space-x-2">
        {isEnabled(CONVERSIONS) && tabSwitcher(CONVERSIONS, 'Goals')}
        {isEnabled(PROPS) && tabSwitcher(PROPS, 'Properties')}
        {isEnabled(FUNNELS) && (hasFunnels() ? tabFunnelPicker() : tabSwitcher(FUNNELS, 'Funnels'))}
      </div>
    )
  }

  function renderConversions() {
    if (site.hasGoals) {
      if (site.flags.props) {
        return <GoalConversions site={site} query={query} />
      } else {
        return <DeprecatedConversions site={site} query={query} />
      }
    }
    else if (adminAccess) {
      return (
        <FeatureSetupNotice
          site={site}
          feature={CONVERSIONS}
          shortFeatureName={'goals'}
          title={'Measure how often visitors complete specific actions'}
          info={'Goals allow you to track registrations, button clicks, form completions, external link clicks, file downloads, 404 error pages and more.'}
          settingsLink={`/${encodeURIComponent(site.domain)}/settings/goals`}
          onHideAction={onHideAction(CONVERSIONS)}
        />
      )
    }
    else { return noDataYet() }
  }

  function renderFunnels() {
    if (selectedFunnel) { return <Funnel site={site} query={query} funnelName={selectedFunnel} /> }
    else if (adminAccess) {
      return (
        <FeatureSetupNotice
          site={site}
          feature={FUNNELS}
          shortFeatureName={'funnels'}
          title={'Follow the visitor journey from entry to conversion'}
          info={'Funnels allow you to analyze the user flow through your website, uncover possible issues, optimize your site and increase the conversion rate.'}
          settingsLink={`/${encodeURIComponent(site.domain)}/settings/funnels`}
          onHideAction={onHideAction(FUNNELS)}
        />
      )
    }
    else { return noDataYet() }
  }

  function renderProps() {
    if (site.hasProps) {
      return <Properties site={site} query={query} />
    } else if (adminAccess) {
      return (
        <FeatureSetupNotice
          site={site}
          feature={PROPS}
          shortFeatureName={'props'}
          title={'No custom properties found'}
          info={'You can attach custom properties when sending a pageview or event. This allows you to create custom metrics and analyze stats we don\'t track automatically.'}
          settingsLink={`/${encodeURIComponent(site.domain)}/settings/properties`}
          onHideAction={onHideAction(PROPS)}
        />
      )
    } else { return noDataYet() }
  }

  function noDataYet() {
    return (
      <div className="font-medium text-gray-500 dark:text-gray-400 py-12 text-center">
        No data yet
      </div>
    )
  }

  function onHideAction(mode) {
    return () => { disableMode(mode) }
  }

  function renderContent() {
    switch (mode) {
      case CONVERSIONS:
        return renderConversions()
      case PROPS:
        return renderProps()
      case FUNNELS:
        return renderFunnels()
    }
  }

  function defaultMode() {
    if (enabledModes.length === 0) { return null }

    const storedMode = storage.getItem(tabKey)
    if (storedMode && enabledModes.includes(storedMode)) { return storedMode }

    if (enabledModes.includes(CONVERSIONS)) { return CONVERSIONS }
    if (enabledModes.includes(PROPS)) { return PROPS }
    return FUNNELS
  }

  function getEnabledModes() {
    let enabledModes = []

    if (site.conversionsEnabled) {
      enabledModes.push(CONVERSIONS)
    }
    if (site.propsEnabled && site.flags.props) {
      enabledModes.push(PROPS)
    }
    if (site.funnelsEnabled && !isRealtime() && site.flags.funnels) {
      enabledModes.push(FUNNELS)
    }
    return enabledModes
  }

  function isEnabled(mode) {
    return enabledModes.includes(mode)
  }

  function isRealtime() {
    return query.period === 'realtime'
  }

  function sectionTitle() {
    if (mode === CONVERSIONS) {
      return specialTitleWhenGoalFilter(query, sectionTitles[mode])
    } else {
      return sectionTitles[mode]
    }
  }

  if (mode) {
    return (
      <div className="items-start justify-between block w-full mt-6 md:flex">
        <div className="w-full p-4 bg-white rounded shadow-xl dark:bg-gray-825">
          <div className="flex justify-between w-full">
            <h3 className="font-bold dark:text-gray-100">
              {sectionTitle() + (isRealtime() ? ' (last 30min)' : '')}
            </h3>
            {tabs()}
          </div>
          {renderContent()}
        </div>
      </div>
    )
  } else {
    return null
  }
}
