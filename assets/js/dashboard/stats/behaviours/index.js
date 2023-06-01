import React, { Fragment, useState } from 'react'
import { Menu, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import * as storage from '../../util/storage'

import Conversions from './conversions'

const ACTIVE_CLASS = 'inline-block h-5 text-indigo-700 dark:text-indigo-500 font-bold active-prop-heading truncate text-left'
const DEFAULT_CLASS = 'hover:text-indigo-600 cursor-pointer truncate text-left'
const CONVERSIONS = 'conversions'
const FUNNELS = 'funnels'

export const sectionTitles = {
  [CONVERSIONS]: 'Goal Conversions',
  [FUNNELS]: "Funnels"
}

export default function Behaviours(props) {
  const tabKey = `behavioursTab__${props.site.domain}`
  const funnelKey = `behavioursTabFunnel__${props.site.domain}`
  
  const [mode, setMode] = useState(storage.getItem(tabKey) || CONVERSIONS)
  const [funnelNames, setFunnelNames] = useState(props.site.funnels.map(({ name }) => name))
  const [selectedFunnel, setSelectedFunnel] = useState(storage.getItem(funnelKey))
  
  function setConversions() {
    return () => {
      storage.setItem(tabKey, CONVERSIONS)
      setMode(CONVERSIONS)
    }
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
    const site = props.site
    return site.flags.funnels && site.funnels.length > 0
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
                        mode === funnelName ? 'font-bold' : ''
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

  function tabConversions() {
    return (
      <div className={classNames({ [ACTIVE_CLASS]: mode == CONVERSIONS, [DEFAULT_CLASS]: mode !== CONVERSIONS })} onClick={setConversions()}>Conversions</div>
    )
  }

  function tabs() {
    return (
      <div className="flex text-xs font-medium text-gray-500 dark:text-gray-400 space-x-2">
        {tabConversions()}
        {hasFunnels() ? tabFunnelPicker() : null}
      </div>
    )
  }

  function renderContent() {
    switch (mode) {
      case CONVERSIONS:
        return <Conversions site={props.site} query={props.query} />
      case FUNNELS:
        return null
    }
  }

  return (
    <div className="items-start justify-between block w-full mt-6 md:flex">
      <div className="w-full p-4 bg-white rounded shadow-xl dark:bg-gray-825">
        <div className="flex justify-between w-full">
              <h3 className="font-bold dark:text-gray-100">{ sectionTitles[CONVERSIONS] }</h3>
              {tabs()}
            </div>
        {renderContent()}
      </div>
    </div>
  )
}
