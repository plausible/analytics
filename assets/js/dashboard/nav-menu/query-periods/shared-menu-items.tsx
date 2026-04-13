import React, { ReactNode, RefObject } from 'react'
import classNames from 'classnames'
import { popover } from '../../components/popover'
import { CalendarIcon } from '@heroicons/react/24/outline'
import { Popover, Transition } from '@headlessui/react'

export const linkClassName = classNames(
  popover.items.classNames.navigationLink,
  popover.items.classNames.selectedOption,
  popover.items.classNames.hoverLink
)

export const hiddenCalendarButtonClassName = 'flex h-8 w-0 outline-none'

export const DateMenuCalendarIcon = () => <CalendarIcon className="size-4" />

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
      as="div"
      {...popover.transition.props}
      className={classNames(
        popover.transition.classNames.fullwidth,
        'md:left-auto md:origin-top-right',
        className
      )}
    >
      <Popover.Panel ref={ref} className={calendarPositionClassName}>
        {children}
      </Popover.Panel>
    </Transition>
  )
})
