/* @format */
import React, { useLayoutEffect, useRef } from 'react'
import DatePicker from 'react-flatpickr'

export interface DateRangeCalendarProps {
  id: string
  minDate?: string
  maxDate?: string
  defaultDates?: [string, string]
  onCloseWithNoSelection?: () => void
  onCloseWithSelection?: ([selectionStart, selectionEnd]: [Date, Date]) => void
}

export function DateRangeCalendar({
  id,
  minDate,
  maxDate,
  defaultDates,
  onCloseWithNoSelection,
  onCloseWithSelection
}: DateRangeCalendarProps) {
  const hideInputFieldClassName = '!invisible !h-0 !w-0 !p-0 !m-0 !border-0'
  const calendarRef = useRef<DatePicker>(null)
  useLayoutEffect(() => {
    // on Safari, this removes little arrow pointing to (hidden) input,
    // which didn't appear with other browsers
    calendarRef.current?.flatpickr?.calendarContainer?.classList.remove(
      'arrowTop',
      'arrowBottom',
      'arrowLeft',
      'arrowRight'
    )
  }, [])
  return (
    <DatePicker
      ref={calendarRef}
      className={hideInputFieldClassName}
      id={id}
      options={{
        animate: false,
        inline: true,
        mode: 'range',
        maxDate,
        minDate,
        defaultDate: defaultDates,
        showMonths: 1
      }}
      onClose={
        onCloseWithSelection || onCloseWithNoSelection
          ? ([selectionStart, selectionEnd]) => {
              if (selectionStart && selectionEnd) {
                if (onCloseWithSelection) {
                  onCloseWithSelection([selectionStart, selectionEnd])
                }
              } else {
                if (onCloseWithNoSelection) {
                  onCloseWithNoSelection()
                }
              }
            }
          : undefined
      }
    />
  )
}
