/* @format */
import React from 'react'
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
  return (
    <DatePicker
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
