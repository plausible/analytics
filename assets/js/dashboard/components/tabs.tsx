import {
  CloseButton,
  Popover,
  PopoverButton,
  PopoverPanel,
  Transition
} from '@headlessui/react'
import classNames from 'classnames'
import React, { ReactNode, useRef } from 'react'
import { BlurMenuButtonOnEscape } from '../keybinding'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import { popover } from './popover'

export const TabWrapper = ({
  className,
  children
}: {
  className?: string
  children: ReactNode
}) => (
  <div
    className={classNames(
      'flex text-xs font-medium text-gray-500 dark:text-gray-400 space-x-2 items-center',
      className
    )}
  >
    {children}
  </div>
)

const TabButtonText = ({
  children,
  active
}: {
  children: ReactNode
  active: boolean
}) => (
  <span
    className={classNames({
      'hover:text-indigo-600 cursor-pointer': !active,
      'inline-block h-5 text-indigo-700 dark:text-indigo-500 font-bold underline decoration-2 decoration-indigo-700 dark:decoration-indigo-500':
        active
    })}
  >
    {children}
  </span>
)

export const TabButton = ({
  className,
  children,
  onClick,
  active
}: {
  className?: string
  children: ReactNode
  onClick: () => void
  active: boolean
}) => (
  <button
    className={classNames('truncate text-left', className)}
    onClick={onClick}
  >
    <TabButtonText active={active}>{children}</TabButtonText>
  </button>
)

export const DropdownTabButton = ({
  className,
  transitionClassName,
  active,
  children,
  options
}: {
  className?: string
  transitionClassName?: string
  active: boolean
  children: ReactNode
  options: Array<{ selected: boolean; onClick: () => void; label: string }>
}) => {
  const dropdownButtonRef = useRef<HTMLButtonElement>(null)

  return (
    <Popover className={className}>
      <BlurMenuButtonOnEscape targetRef={dropdownButtonRef} />
      <PopoverButton
        className={classNames('inline-flex justify-between')}
        ref={dropdownButtonRef}
      >
        <TabButtonText active={active}>{children}</TabButtonText>
        <ChevronDownIcon className="-mr-1 ml-1 h-4 w-4" aria-hidden="true" />
      </PopoverButton>

      <Transition
        as="div"
        {...popover.transition.props}
        className={classNames(
          'mt-2',
          popover.transition.classNames.fullwidth,
          transitionClassName
        )}
      >
        <PopoverPanel className={popover.panel.classNames.roundedSheet}>
          {options.map(({ selected, label, onClick }, index) => {
            return (
              <CloseButton
                key={index}
                as="button"
                onClick={onClick}
                data-selected={selected}
                className={classNames(
                  'w-full text-left',
                  popover.items.classNames.navigationLink,
                  popover.items.classNames.selectedOption,
                  popover.items.classNames.hoverLink,
                  popover.items.classNames.roundedStartEnd
                )}
              >
                {label}
              </CloseButton>
            )
          })}
        </PopoverPanel>
      </Transition>
    </Popover>
  )
}
