/** @format */

import { TransitionClasses } from '@headlessui/react'

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

export const popover = {
  panel,
  transition
}
