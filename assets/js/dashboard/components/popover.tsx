import React, { RefObject, useEffect } from 'react'
import classNames from 'classnames'
import { useRoutelessModalsContext } from '../navigation/routeless-modals-context'
import { isModifierPressed, isTyping, Keybind } from '../keybinding'

const transitionClasses = classNames(
  'transition ease-in-out',
  // Shared closed styles
  'data-[closed]:opacity-0',
  // Entering styles
  'ease-out data-[enter]:duration-100 data-[enter]:data-[closed]:scale-95 data-[enter]:scale-100',
  // Leaving styles
  'ease-in data-[leave]:duration-75 data-[leave]:data-[closed]:scale-95 data-[leave]:scale-100'
)

const transition = {
  props: {},
  classNames: {
    fullwidth: classNames(transitionClasses, 'z-10 absolute left-0 right-0'),
    left: classNames(transitionClasses, 'z-10 absolute left-0'),
    right: classNames(transitionClasses, 'z-10 absolute right-0')
  }
}

const panel = {
  classNames: {
    roundedSheet:
      'focus:outline-none rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 font-medium text-gray-800 dark:text-gray-200'
  }
}

const toggleButton = {
  classNames: {
    rounded: 'flex items-center rounded text-sm leading-tight h-9',
    shadow:
      'bg-white dark:bg-gray-800 shadow text-gray-800 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-900',
    ghost:
      'text-gray-700 dark:text-gray-100 hover:bg-gray-200 dark:hover:bg-gray-900',
    truncatedText: 'truncate block font-medium',
    linkLike:
      'text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-600'
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
      'dark:hover:bg-gray-900',
      'dark:hover:text-gray-100',

      'focus-within:bg-gray-100',
      'focus-within:text-gray-900',
      'dark:focus-within:bg-gray-900',
      'dark:focus-within:text-gray-100'
    ),
    roundedStartEnd: classNames(
      'first-of-type:rounded-t-md',
      'last-of-type:rounded-b-md'
    ),
    roundedEnd: classNames('last-of-type:rounded-b-md'),
    groupRoundedStartEnd: classNames(
      'group-first-of-type:rounded-t-md',
      'group-last-of-type:rounded-b-md'
    )
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
  targetRef,
  ...props
}: {
  buttonId?: string
  targetRef: RefObject<HTMLElement>
}) {
  const { registerDropmenuState } = useRoutelessModalsContext()

  useEffect(() => {
    const buttonId =
      props.buttonId ?? `button-${Math.floor(Math.random() * 10000)}`

    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (
          mutation.type === 'attributes' &&
          mutation.attributeName === 'data-open'
        ) {
          const element = mutation.target as Element
          registerDropmenuState({
            id: buttonId,
            isOpen: element.hasAttribute('data-open')
          })
        }
      })
    })

    const element = targetRef.current

    if (element) {
      registerDropmenuState({
        id: buttonId,
        isOpen: element.hasAttribute('data-open')
      })
      observer.observe(element, {
        attributes: true,
        attributeFilter: ['data-open']
      })
    }

    return () => {
      if (element) {
        registerDropmenuState({ id: buttonId, isOpen: false })
      }
      observer.disconnect()
    }
  }, [targetRef, registerDropmenuState, props.buttonId])

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
