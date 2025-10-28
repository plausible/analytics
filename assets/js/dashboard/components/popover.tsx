import React, { RefObject } from 'react'
import classNames from 'classnames'
import { isModifierPressed, isTyping, Keybind } from '../keybinding'
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
  props: {
    ...TRANSITION_CONFIG
  },
  classNames: {
    fullwidth: 'z-10 absolute left-0 right-0 origin-top',
    left: 'z-10 absolute left-0 origin-top-left',
    right: 'z-10 absolute right-0 origin-top-right'
  }
}

const panel = {
  classNames: {
    roundedSheet:
      'focus:outline-hidden rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black/5 font-medium text-gray-800 dark:text-gray-200'
  }
}

const toggleButton = {
  classNames: {
    rounded:
      'flex items-center rounded text-sm leading-tight h-9 transition-all duration-150',
    shadow:
      'bg-white dark:bg-gray-750 shadow-sm text-gray-800 dark:text-gray-200 dark:hover:bg-gray-700',
    ghost:
      'text-gray-700 dark:text-gray-100 hover:bg-gray-200 dark:hover:bg-gray-900',
    truncatedText: 'truncate block font-medium',
    linkLike:
      'text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-gray-100 transition-colors duration-150'
  }
}

const items = {
  classNames: {
    navigationLink: classNames(
      'flex items-center justify-between',
      'px-4 py-2 text-sm leading-tight',
      'cursor-pointer'
    ),
    selectedOption: classNames('data-[selected=true]:font-bold'),
    hoverLink: classNames(
      'hover:bg-gray-100',
      'hover:text-gray-900',
      'dark:hover:bg-gray-700',
      'dark:hover:text-gray-100',

      'focus-within:bg-gray-100',
      'focus-within:text-gray-900',
      'dark:focus-within:bg-gray-700',
      'dark:focus-within:text-gray-100'
    ),
    roundedStart: 'first-of-type:rounded-t-md',
    roundedEnd: 'last-of-type:rounded-b-md',
    groupRoundedEnd: 'group-last-of-type:rounded-b-md'
  }
}

export const popover = {
  toggleButton,
  panel,
  transition,
  items
}

/**
 * Rendering this component captures the Escape key on targetRef.current, a PopoverButton,
 * blurring the element on Escape, and stopping the event from propagating.
 * Needed to prevent other Escape handlers that may exist from running.
 */
export function BlurMenuButtonOnEscape({
  targetRef
}: {
  targetRef: RefObject<HTMLElement>
}) {
  return (
    <Keybind
      keyboardKey="Escape"
      type="keyup"
      handler={(event) => {
        const t = event.target as HTMLElement | null
        if (typeof t?.blur === 'function') {
          if (t === targetRef.current) {
            t.blur()
            event.stopPropagation()
          }
        }
      }}
      targetRef={targetRef}
      shouldIgnoreWhen={[isModifierPressed, isTyping]}
    />
  )
}
