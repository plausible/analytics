import React, { Fragment } from 'react'
import { Menu, Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import * as storage from '../../util/storage'

import Funnel from './funnel'
import Conversions from './conversions'

const ACTIVE_CLASS = 'inline-block h-5 text-indigo-700 dark:text-indigo-500 font-bold active-prop-heading truncate text-left'
const DEFAULT_CLASS = 'hover:text-indigo-600 cursor-pointer truncate text-left'
const CONVERSIONS = 'conversions'
const FUNNELS = 'funnels'

export default class Behaviours extends React.Component {
  constructor(props) {
    super(props)
    this.tabKey = `behavioursTab__${props.site.domain}`
    this.funnelKey = `behavioursTabFunnel__${props.site.domain}`

    const storedTab = storage.getItem(this.tabKey)
    const storedFunnelName = storage.getItem(this.funnelKey)

    const funnelNames = props.site.funnels.map(({ name }) => name)

    this.state = {
      mode: storedTab || CONVERSIONS,
      funnelNames: funnelNames,
      selectedFunnelName: storedFunnelName
    }
  }

  setConversions() {
    return () => {
      storage.setItem(this.tabKey, CONVERSIONS)
      this.setState({ mode: CONVERSIONS })
    }
  }

  setFunnel(selectedFunnelName) {
    return () => {
      storage.setItem(this.tabKey, FUNNELS)
      storage.setItem(this.funnelKey, selectedFunnelName)
      this.setState({ mode: FUNNELS, selectedFunnelName: selectedFunnelName })
    }
  }

  hasFunnels() {
    const site = this.props.site
    return site.flags.funnels && site.funnels.length > 0
  }

  tabFunnelPicker() {
    return <Menu as="div" className="relative inline-block text-left">
      <div>
        <Menu.Button className="inline-flex justify-between focus:outline-none">
          <span className={(this.state.mode == FUNNELS) ? ACTIVE_CLASS : DEFAULT_CLASS}>Funnels</span>
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
            {this.state.funnelNames.map((funnelName) => {
              return (
                <Menu.Item key={funnelName}>
                  {({ active }) => (
                    <span
                      onClick={this.setFunnel(funnelName)}
                      className={classNames(
                        active ? 'bg-gray-100 dark:bg-gray-900 text-gray-900 dark:text-gray-200 cursor-pointer' : 'text-gray-700 dark:text-gray-200',
                        'block px-4 py-2 text-sm',
                        this.state.mode === funnelName ? 'font-bold' : ''
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

  tabConversions() {
    return (
      <div className={classNames({ [ACTIVE_CLASS]: this.state.mode == CONVERSIONS, [DEFAULT_CLASS]: this.state.mode !== CONVERSIONS })} onClick={this.setConversions()}>Conversions</div>
    )
  }

  tabs() {
    return (
      <div className="flex text-xs font-medium text-gray-500 dark:text-gray-400 space-x-2">
        {this.tabConversions()}
        {this.hasFunnels() ? this.tabFunnelPicker() : null}
      </div>
    )
  }

  renderContent() {
    switch (this.state.mode) {
      case CONVERSIONS:
        return <Conversions tabs={this.tabs()} site={this.props.site} query={this.props.query} />
      case FUNNELS:
        return <Funnel tabs={this.tabs()} funnelName={this.state.selectedFunnelName} query={this.props.query} site={this.props.site} />
    }
  }

  render() {
    return (<div className="w-full p-4 bg-white rounded shadow-xl dark:bg-gray-825">
      {this.renderContent()}
    </div>)
  }
}
