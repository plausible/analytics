/** @format */
import React from 'react'
import { TransitionClasses } from '@headlessui/react'
import classNames from 'classnames'

const TRANSITION_CONFIG: TransitionClasses = {
  enter: 'transition ease-out duration-100',
  enterFrom: 'opacity-0 scale-95',
  enterTo: 'opacity-100 scale-100',
  leave: 'transition ease-in duration-75',
  leaveFrom: 'opacity-100 scale-100',
  leaveTo: 'opacity-0 scale-95'
}

const transition = {
  props: TRANSITION_CONFIG,
  classNames: { fullwidth: 'z-10 absolute left-0 right-0' }
}

const panel = {
  classNames: {
    roundedSheet:
      'focus:outline-none rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 font-medium text-gray-800 dark:text-gray-200'
  }
}

const toggleButton = {
  classNames: {}
}

const items = {
  classNames: {
    navigationLink: classNames(
      'flex items-center justify-between',
      'px-4 py-2 text-sm leading-tight'
    ),
    disabledLink: classNames(
      'data-[headlessui-state=disabled]:font-bold',
      'data-[headlessui-state=disabled]:cursor-default'
    ),
    activeLink: classNames(
      'data-[headlessui-state=active]:bg-gray-100',
      'data-[headlessui-state=active]:text-gray-900',
      'dark:data-[headlessui-state=active]:bg-gray-900',
      'dark:data-[headlessui-state=active]:text-gray-100'
    ),
    hoverLink: classNames(
      'hover:bg-gray-100',
      'hover:text-gray-900',
      'dark:hover:bg-gray-900',
      'dark:hover:text-gray-100'
    )
  }
}

export const popover = {
  toggleButton,
  panel,
  transition,
  items
}

export const MenuSeparator = () => (
  <div className="my-1 border-gray-200 dark:border-gray-500 border-b" />
)
