/** @format */

import React, { useEffect } from 'react'
import classNames from 'classnames'
import { popover } from '../../components/popover'
import { ChevronDownIcon } from '@heroicons/react/20/solid'

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

export const DateMenuChevron = () => (
  <ChevronDownIcon className="hidden lg:inline-block h-4 w-4 md:h-5 md:w-5 ml-1 md:ml-2 text-gray-500" />
)

export const MenuSeparator = () => (
  <div className="my-1 border-gray-200 dark:border-gray-500 border-b" />
)

export interface DropdownItemsProps {
  dropdownIsOpen: boolean
  calendarIsOpen: boolean
  closeDropdown: () => void
  openCalendar: () => void
  closeCalendar: () => void
}

export const useCloseCalendarOnDropdownOpen = ({
  dropdownIsOpen,
  calendarIsOpen,
  closeCalendar
}: Pick<
  DropdownItemsProps,
  'dropdownIsOpen' | 'calendarIsOpen' | 'closeCalendar'
>) => {
  useEffect(() => {
    if (dropdownIsOpen && calendarIsOpen) {
      closeCalendar()
    }
  }, [dropdownIsOpen, calendarIsOpen, closeCalendar])
}
