import React from 'react'
import { render, screen } from '@testing-library/react'
import { DateRangeCalendar } from './date-range-calendar'
import userEvent from '@testing-library/user-event'

test('renders with default dates in view, respects max and min dates', async () => {
  const onCloseWithNoSelection = jest.fn()
  const onCloseWithSelection = jest.fn()
  const handlers = { onCloseWithNoSelection, onCloseWithSelection }

  render(
    <DateRangeCalendar
      id="calendar"
      minDate="2024-09-10"
      maxDate="2024-09-25"
      defaultDates={['2024-09-12', '2024-09-19']}
      {...handlers}
    />
  )

  const days = await screen.queryAllByLabelText(/, 2024/)

  expect(
    days.map((d) => [d.getAttribute('aria-label'), d.getAttribute('class')])
  ).toEqual([
    ['September 1, 2024', 'flatpickr-day flatpickr-disabled'],
    ['September 2, 2024', 'flatpickr-day flatpickr-disabled'],
    ['September 3, 2024', 'flatpickr-day flatpickr-disabled'],
    ['September 4, 2024', 'flatpickr-day flatpickr-disabled'],
    ['September 5, 2024', 'flatpickr-day flatpickr-disabled'],
    ['September 6, 2024', 'flatpickr-day flatpickr-disabled'],
    ['September 7, 2024', 'flatpickr-day flatpickr-disabled'],
    ['September 8, 2024', 'flatpickr-day flatpickr-disabled'],
    ['September 9, 2024', 'flatpickr-day flatpickr-disabled'],
    ['September 10, 2024', 'flatpickr-day'],
    ['September 11, 2024', 'flatpickr-day'],
    ['September 12, 2024', 'flatpickr-day selected startRange'],
    ['September 13, 2024', 'flatpickr-day inRange'],
    ['September 14, 2024', 'flatpickr-day inRange'],
    ['September 15, 2024', 'flatpickr-day inRange'],
    ['September 16, 2024', 'flatpickr-day inRange'],
    ['September 17, 2024', 'flatpickr-day inRange'],
    ['September 18, 2024', 'flatpickr-day inRange'],
    ['September 19, 2024', 'flatpickr-day selected endRange'],
    ['September 20, 2024', 'flatpickr-day'],
    ['September 21, 2024', 'flatpickr-day'],
    ['September 22, 2024', 'flatpickr-day'],
    ['September 23, 2024', 'flatpickr-day'],
    ['September 24, 2024', 'flatpickr-day'],
    ['September 25, 2024', 'flatpickr-day'],
    ['September 26, 2024', 'flatpickr-day flatpickr-disabled'],
    ['September 27, 2024', 'flatpickr-day flatpickr-disabled'],
    ['September 28, 2024', 'flatpickr-day flatpickr-disabled'],
    ['September 29, 2024', 'flatpickr-day flatpickr-disabled'],
    ['September 30, 2024', 'flatpickr-day flatpickr-disabled'],
    ['October 1, 2024', 'flatpickr-day nextMonthDay flatpickr-disabled'],
    ['October 2, 2024', 'flatpickr-day nextMonthDay flatpickr-disabled'],
    ['October 3, 2024', 'flatpickr-day nextMonthDay flatpickr-disabled'],
    ['October 4, 2024', 'flatpickr-day nextMonthDay flatpickr-disabled'],
    ['October 5, 2024', 'flatpickr-day nextMonthDay flatpickr-disabled'],
    ['October 6, 2024', 'flatpickr-day nextMonthDay flatpickr-disabled'],
    ['October 7, 2024', 'flatpickr-day nextMonthDay flatpickr-disabled'],
    ['October 8, 2024', 'flatpickr-day nextMonthDay flatpickr-disabled'],
    ['October 9, 2024', 'flatpickr-day nextMonthDay flatpickr-disabled'],
    ['October 10, 2024', 'flatpickr-day nextMonthDay flatpickr-disabled'],
    ['October 11, 2024', 'flatpickr-day nextMonthDay flatpickr-disabled'],
    ['October 12, 2024', 'flatpickr-day nextMonthDay flatpickr-disabled']
  ])

  const newStart = await screen.getByLabelText('September 20, 2024')
  await userEvent.click(newStart)
  const newEnd = await screen.getByLabelText('September 25, 2024')
  await userEvent.click(newEnd)

  expect(onCloseWithSelection).toHaveBeenCalledTimes(1)
  expect(onCloseWithSelection).toHaveBeenLastCalledWith([
    new Date('2024-09-20'),
    new Date('2024-09-25')
  ])
})
