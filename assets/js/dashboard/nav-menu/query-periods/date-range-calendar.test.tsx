import React from 'react'
import { render, screen } from '@testing-library/react'
import { DateRangeCalendar } from './date-range-calendar'
import userEvent from '@testing-library/user-event'

test('renders with default dates in view, respects max and min dates', async () => {
  const onCloseWithSelection = jest.fn()

  render(
    <DateRangeCalendar
      id="calendar"
      minDate="2024-09-10"
      maxDate="2024-09-25"
      defaultDates={['2024-09-12', '2024-09-19']}
      onCloseWithSelection={onCloseWithSelection}
    />
  )

  const days = await screen.queryAllByLabelText(/, 2024/)

  const expectState = (
    el: Element
  ): Array<'disabled' | 'outsideMonth' | 'selected' | 'inRange'> => {
    const states: Array<'disabled' | 'outsideMonth' | 'selected' | 'inRange'> =
      []
    if (el.getAttribute('aria-disabled') === 'true') states.push('disabled')
    if (el.getAttribute('data-outside-month') === 'true')
      states.push('outsideMonth')
    if (el.getAttribute('data-selected') === 'true') states.push('selected')
    if (el.getAttribute('data-in-range') === 'true') states.push('inRange')
    return states
  }

  expect(
    days.map((d) => [d.getAttribute('aria-label'), expectState(d)])
  ).toEqual([
    ['September 1, 2024', ['disabled']],
    ['September 2, 2024', ['disabled']],
    ['September 3, 2024', ['disabled']],
    ['September 4, 2024', ['disabled']],
    ['September 5, 2024', ['disabled']],
    ['September 6, 2024', ['disabled']],
    ['September 7, 2024', ['disabled']],
    ['September 8, 2024', ['disabled']],
    ['September 9, 2024', ['disabled']],
    ['September 10, 2024', []],
    ['September 11, 2024', []],
    ['September 12, 2024', ['selected']],
    ['September 13, 2024', ['inRange']],
    ['September 14, 2024', ['inRange']],
    ['September 15, 2024', ['inRange']],
    ['September 16, 2024', ['inRange']],
    ['September 17, 2024', ['inRange']],
    ['September 18, 2024', ['inRange']],
    ['September 19, 2024', ['selected']],
    ['September 20, 2024', []],
    ['September 21, 2024', []],
    ['September 22, 2024', []],
    ['September 23, 2024', []],
    ['September 24, 2024', []],
    ['September 25, 2024', []],
    ['September 26, 2024', ['disabled']],
    ['September 27, 2024', ['disabled']],
    ['September 28, 2024', ['disabled']],
    ['September 29, 2024', ['disabled']],
    ['September 30, 2024', ['disabled']],
    ['October 1, 2024', ['disabled', 'outsideMonth']],
    ['October 2, 2024', ['disabled', 'outsideMonth']],
    ['October 3, 2024', ['disabled', 'outsideMonth']],
    ['October 4, 2024', ['disabled', 'outsideMonth']],
    ['October 5, 2024', ['disabled', 'outsideMonth']],
    ['October 6, 2024', ['disabled', 'outsideMonth']],
    ['October 7, 2024', ['disabled', 'outsideMonth']],
    ['October 8, 2024', ['disabled', 'outsideMonth']],
    ['October 9, 2024', ['disabled', 'outsideMonth']],
    ['October 10, 2024', ['disabled', 'outsideMonth']],
    ['October 11, 2024', ['disabled', 'outsideMonth']],
    ['October 12, 2024', ['disabled', 'outsideMonth']]
  ])

  const newStart = await screen.getByLabelText('September 20, 2024')
  await userEvent.click(newStart)
  const newEnd = await screen.getByLabelText('September 25, 2024')
  await userEvent.click(newEnd)

  expect(onCloseWithSelection).toHaveBeenCalledTimes(1)
  expect(onCloseWithSelection).toHaveBeenLastCalledWith([
    new Date(2024, 8, 20),
    new Date(2024, 8, 25)
  ])
})

test('supports keyboard navigation for selecting a range', async () => {
  const onCloseWithSelection = jest.fn()
  const user = userEvent.setup()

  render(
    <DateRangeCalendar
      id="calendar"
      minDate="2024-09-01"
      maxDate="2024-09-30"
      defaultDates={['2024-09-10', '2024-09-10']}
      onCloseWithSelection={onCloseWithSelection}
    />
  )

  const initialFocus = screen.getByLabelText('September 10, 2024')
  initialFocus.focus()
  expect(initialFocus).toHaveFocus()

  await user.keyboard('{ArrowRight}')
  expect(screen.getByLabelText('September 11, 2024')).toHaveFocus()

  await user.keyboard('{ArrowDown}')
  expect(screen.getByLabelText('September 18, 2024')).toHaveFocus()

  await user.keyboard('{Enter}')

  await user.keyboard('{ArrowRight>3/}')
  expect(screen.getByLabelText('September 21, 2024')).toHaveFocus()

  await user.keyboard('{Enter}')

  expect(onCloseWithSelection).toHaveBeenCalledTimes(1)
  expect(onCloseWithSelection).toHaveBeenLastCalledWith([
    new Date(2024, 8, 18),
    new Date(2024, 8, 21)
  ])
})

test('keyboard navigation across month boundaries shifts the visible month', async () => {
  const user = userEvent.setup()

  render(
    <DateRangeCalendar
      id="calendar"
      minDate="2024-08-01"
      maxDate="2024-10-31"
      defaultDates={['2024-09-01', '2024-09-01']}
    />
  )

  const sep1 = screen.getByLabelText('September 1, 2024')
  sep1.focus()
  expect(sep1).toHaveFocus()

  await user.keyboard('{ArrowLeft}')
  expect(screen.getByLabelText('August 31, 2024')).toHaveFocus()

  await user.keyboard('{PageDown}')
  expect(screen.getByLabelText('September 30, 2024')).toHaveFocus()
})

test('month dropdown only offers months that contain selectable days', async () => {
  render(
    <DateRangeCalendar
      id="calendar"
      minDate="2024-04-15"
      maxDate="2024-09-20"
      defaultDates={['2024-09-01', '2024-09-01']}
    />
  )

  const monthSelect = screen.getByLabelText('Month') as HTMLSelectElement
  const labels = Array.from(monthSelect.options).map((o) => o.textContent)
  expect(labels).toEqual([
    'April',
    'May',
    'June',
    'July',
    'August',
    'September'
  ])
})

test('changing year clamps the visible month to stay within bounds', async () => {
  const user = userEvent.setup()

  render(
    <DateRangeCalendar
      id="calendar"
      minDate="2023-01-01"
      maxDate="2024-09-20"
      defaultDates={['2023-11-15', '2023-11-15']}
    />
  )

  expect(screen.getByLabelText('November 15, 2023')).toBeInTheDocument()

  const yearSelect = screen.getByLabelText('Year') as HTMLSelectElement
  await user.selectOptions(yearSelect, '2024')

  expect(screen.getByLabelText('Month')).toHaveValue('8')
  expect(screen.getByLabelText('September 20, 2024')).toBeInTheDocument()
})

test('does not allow keyboard navigation beyond minDate/maxDate', async () => {
  const user = userEvent.setup()

  render(
    <DateRangeCalendar
      id="calendar"
      minDate="2024-09-10"
      maxDate="2024-09-20"
      defaultDates={['2024-09-10', '2024-09-10']}
    />
  )

  const sep10 = screen.getByLabelText('September 10, 2024')
  sep10.focus()

  await user.keyboard('{ArrowLeft}')
  expect(screen.getByLabelText('September 10, 2024')).toHaveFocus()

  for (let i = 0; i < 20; i++) {
    await user.keyboard('{ArrowRight}')
  }
  expect(screen.getByLabelText('September 20, 2024')).toHaveFocus()
})
