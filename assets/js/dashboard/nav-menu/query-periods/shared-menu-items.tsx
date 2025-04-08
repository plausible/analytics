import React, { ReactNode, RefObject } from 'react'
import classNames from 'classnames'
import { popover } from '../../components/popover'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import { Popover, Transition } from '@headlessui/react'

export const linkClassName = classNames(
  popover.items.classNames.navigationLink,
  popover.items.classNames.selectedOption,
  popover.items.classNames.hoverLink,
  popover.items.classNames.roundedStartEnd
)

export const datemenuButtonClassName = classNames(
  popover.toggleButton.classNames.rounded,
  popover.toggleButton.classNames.shadow,
  'justify-between px-2 w-full'
)

export const hiddenCalendarButtonClassName = 'flex h-9 w-0 outline-none'

export const DateMenuChevron = () => (
  <ChevronDownIcon className="hidden lg:inline-block h-4 w-4 md:h-5 md:w-5 ml-1 md:ml-2 text-gray-500" />
)

export interface PopoverMenuProps {
  closeDropdown: () => void
  calendarButtonRef: RefObject<HTMLButtonElement>
}

const calendarPositionClassName = '*:!top-auto *:!right-0 *:!absolute'

type CalendarPanelProps = {
  className?: string
  children: ReactNode
}

export const CalendarPanel = React.forwardRef<
  HTMLDivElement,
  CalendarPanelProps
>(({ children, className }, ref) => {
  return (
    <Transition
      {...popover.transition.props}
      className={classNames(
        popover.transition.classNames.fullwidth,
        'md:left-auto',
        className
      )}
    >
      <Popover.Panel ref={ref} className={calendarPositionClassName}>
        {children}
      </Popover.Panel>
    </Transition>
  )
})
