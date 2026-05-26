import React, {
  KeyboardEvent,
  ReactNode,
  Ref,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState
} from 'react'
import classNames from 'classnames'
import {
  ChevronLeftIcon,
  ChevronRightIcon,
  ChevronUpDownIcon
} from '@heroicons/react/20/solid'
import dayjs, { Dayjs } from 'dayjs'

export interface DateRangeCalendarProps {
  id: string
  minDate?: string
  maxDate?: string
  defaultDates?: [string, string]
  /**
   * ISO date string (YYYY-MM-DD) to highlight as "today". Defaults to the
   * browser's local current date. Pass the site's current date if you need
   * the indicator to follow the site's timezone.
   */
  today?: string
  onCloseWithSelection?: ([selectionStart, selectionEnd]: [Date, Date]) => void
}

const MONTHS = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December'
]

const WEEKDAY_LABELS = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']

const parseISO = (value: string): Dayjs => dayjs(value).startOf('day')

const ariaLabel = (date: Dayjs): string => date.format('MMMM D, YYYY')

// Return a Date at LOCAL midnight (matches what `dayjs(date)` will read back).
// `new Date('YYYY-MM-DD')` parses as UTC midnight and would shift the day in
// negative-offset timezones when callers reformat the date in local time.
const toNativeDate = (date: Dayjs): Date =>
  new Date(date.year(), date.month(), date.date())

const clamp = (date: Dayjs, min?: Dayjs, max?: Dayjs): Dayjs => {
  let result = date
  if (min && result.isBefore(min, 'day')) result = min
  if (max && result.isAfter(max, 'day')) result = max
  return result
}

// Returns the Dayjs that focus should move to for a given key, or null when
// the key is not a navigation key.
const getNextFocusedDate = (day: Dayjs, event: KeyboardEvent): Dayjs | null => {
  switch (event.key) {
    case 'ArrowLeft':
      return day.subtract(1, 'day')
    case 'ArrowRight':
      return day.add(1, 'day')
    case 'ArrowUp':
      return day.subtract(1, 'week')
    case 'ArrowDown':
      return day.add(1, 'week')
    case 'Home':
      return day.startOf('week')
    case 'End':
      return day.endOf('week')
    case 'PageUp':
      return event.shiftKey ? day.subtract(1, 'year') : day.subtract(1, 'month')
    case 'PageDown':
      return event.shiftKey ? day.add(1, 'year') : day.add(1, 'month')
    default:
      return null
  }
}

type Selection = { start: Dayjs | null; end: Dayjs | null }
type RangeBounds = { from: Dayjs; to: Dayjs } | null

export function DateRangeCalendar({
  id,
  minDate,
  maxDate,
  defaultDates,
  today: todayProp,
  onCloseWithSelection
}: DateRangeCalendarProps) {
  const min = useMemo(
    () => (minDate ? parseISO(minDate) : undefined),
    [minDate]
  )
  const max = useMemo(
    () => (maxDate ? parseISO(maxDate) : undefined),
    [maxDate]
  )

  const today = useMemo(
    () => (todayProp ? parseISO(todayProp) : dayjs().startOf('day')),
    [todayProp]
  )

  const initialSelection = useMemo<Selection>(() => {
    if (defaultDates) {
      return {
        start: parseISO(defaultDates[0]),
        end: parseISO(defaultDates[1])
      }
    }
    return { start: null, end: null }
  }, [defaultDates])

  const [selection, setSelection] = useState<Selection>(initialSelection)
  const [hoveredDate, setHoveredDate] = useState<Dayjs | null>(null)

  const [viewDate, setViewDate] = useState<Dayjs>(() => {
    const baseline = initialSelection.start ?? max ?? today
    return clamp(baseline, min, max).startOf('month')
  })

  const [focusedDate, setFocusedDate] = useState<Dayjs>(() => {
    const baseline = initialSelection.start ?? today
    return clamp(baseline, min, max)
  })

  const focusedButtonRef = useRef<HTMLButtonElement | null>(null)
  // Focus the grid on mount so keyboard navigation works immediately after
  // the calendar opens. Subsequent moves toggle this flag back on.
  const shouldFocusRef = useRef(true)
  useEffect(() => {
    if (shouldFocusRef.current) {
      focusedButtonRef.current?.focus({ preventScroll: true })
      shouldFocusRef.current = false
    }
  }, [focusedDate, viewDate])

  const isDayDisabled = useCallback(
    (day: Dayjs) => {
      if (min && day.isBefore(min, 'day')) return true
      if (max && day.isAfter(max, 'day')) return true
      return false
    },
    [min, max]
  )

  const handleSelectDay = useCallback(
    (day: Dayjs) => {
      const { start, end } = selection
      if (!start || (start && end)) {
        setSelection({ start: day, end: null })
        return
      }

      const [first, second] = start.isAfter(day, 'day')
        ? [day, start]
        : [start, day]
      setSelection({ start: first, end: second })

      if (onCloseWithSelection) {
        onCloseWithSelection([toNativeDate(first), toNativeDate(second)])
      }
    },
    [selection, onCloseWithSelection]
  )

  const moveFocus = useCallback(
    (next: Dayjs) => {
      const clamped = clamp(next, min, max)
      shouldFocusRef.current = true
      setFocusedDate(clamped)
      if (!clamped.isSame(viewDate, 'month')) {
        setViewDate(clamped.startOf('month'))
      }
    },
    [min, max, viewDate]
  )

  const handleDayKeyDown = useCallback(
    (event: KeyboardEvent<HTMLButtonElement>, day: Dayjs) => {
      const next = getNextFocusedDate(day, event)
      if (!next) return
      event.preventDefault()
      event.stopPropagation()
      moveFocus(next)
    },
    [moveFocus]
  )

  const renderRangeBounds = useMemo<RangeBounds>(() => {
    const { start, end } = selection
    if (start && end) {
      return { from: start, to: end }
    }
    if (start && hoveredDate && !isDayDisabled(hoveredDate)) {
      const [from, to] = start.isAfter(hoveredDate, 'day')
        ? [hoveredDate, start]
        : [start, hoveredDate]
      return { from, to }
    }
    if (start) {
      return { from: start, to: start }
    }
    return null
  }, [selection, hoveredDate, isDayDisabled])

  const days = useMemo(() => {
    const firstOfMonth = viewDate.startOf('month')
    const startWeekday = firstOfMonth.day()
    const gridStart = firstOfMonth.subtract(startWeekday, 'day')
    return Array.from({ length: 42 }, (_, i) => gridStart.add(i, 'day'))
  }, [viewDate])

  return (
    <div
      id={id}
      role="dialog"
      aria-label="Date range calendar"
      className="w-72 select-none p-3 rounded-lg shadow-lg bg-white dark:bg-gray-800 ring-1 ring-gray-150 dark:ring-gray-750"
    >
      <CalendarHeader
        viewDate={viewDate}
        min={min}
        max={max}
        today={today}
        onChangeView={setViewDate}
      />

      <div
        role="grid"
        tabIndex={-1}
        aria-label={viewDate.format('MMMM YYYY')}
        className="grid grid-cols-7 gap-y-0.5"
        onMouseLeave={() => setHoveredDate(null)}
      >
        {WEEKDAY_LABELS.map((day) => (
          <div
            key={day}
            role="columnheader"
            className="h-7 flex items-center justify-center text-xs font-medium text-gray-400 dark:text-gray-500"
          >
            {day}
          </div>
        ))}

        {days.map((day) => (
          <DayCell
            key={day.toString()}
            day={day}
            viewMonth={viewDate.month()}
            today={today}
            focusedDate={focusedDate}
            range={renderRangeBounds}
            disabled={isDayDisabled(day)}
            focusRef={
              day.isSame(focusedDate, 'day') ? focusedButtonRef : undefined
            }
            onSelect={(d) => {
              setFocusedDate(d)
              handleSelectDay(d)
            }}
            onKeyDown={handleDayKeyDown}
            onHover={setHoveredDate}
          />
        ))}
      </div>
    </div>
  )
}

type CalendarHeaderProps = {
  viewDate: Dayjs
  min?: Dayjs
  max?: Dayjs
  today: Dayjs
  onChangeView: React.Dispatch<React.SetStateAction<Dayjs>>
}

function CalendarHeader({
  viewDate,
  min,
  max,
  today,
  onChangeView
}: CalendarHeaderProps) {
  const yearOptions = useMemo(() => {
    const fallbackStart = (min ?? today).year()
    const fallbackEnd = (max ?? today).year()
    const startYear = Math.min(fallbackStart, viewDate.year())
    const endYear = Math.max(fallbackEnd, viewDate.year())
    const years: number[] = []
    for (let y = startYear; y <= endYear; y++) {
      years.push(y)
    }
    return years
  }, [min, max, today, viewDate])

  const monthOptions = useMemo(() => {
    return MONTHS.map((label, index) => ({ label, index })).filter(
      ({ index }) => {
        const monthStart = viewDate.startOf('month').month(index)
        const monthEnd = monthStart.endOf('month')
        if (min && monthEnd.isBefore(min, 'day')) return false
        if (max && monthStart.isAfter(max, 'day')) return false
        return true
      }
    )
  }, [viewDate, min, max])

  const setViewMonth = useCallback(
    (monthIndex: number) => {
      onChangeView((current) => current.startOf('month').month(monthIndex))
    },
    [onChangeView]
  )

  const setViewYear = useCallback(
    (year: number) => {
      onChangeView((current) => {
        const next = current.startOf('month').year(year)
        if (min && next.endOf('month').isBefore(min, 'day')) {
          return min.startOf('month')
        }
        if (max && next.startOf('month').isAfter(max, 'day')) {
          return max.startOf('month')
        }
        return next
      })
    },
    [min, max, onChangeView]
  )

  const isPreviousMonthAvailable = useMemo(() => {
    if (!min) return true
    return !viewDate.subtract(1, 'month').endOf('month').isBefore(min, 'day')
  }, [viewDate, min])

  const isNextMonthAvailable = useMemo(() => {
    if (!max) return true
    return !viewDate.add(1, 'month').startOf('month').isAfter(max, 'day')
  }, [viewDate, max])

  return (
    <div className="flex items-center justify-between gap-2 mb-3">
      <NavButton
        ariaLabel="Previous month"
        disabled={!isPreviousMonthAvailable}
        onClick={() => onChangeView((current) => current.subtract(1, 'month'))}
      >
        <ChevronLeftIcon className="size-4" />
      </NavButton>

      <div className="flex items-center gap-1.5">
        <HeaderSelect
          ariaLabel="Month"
          value={viewDate.month()}
          onChange={(value) => setViewMonth(Number(value))}
        >
          {monthOptions.map(({ label, index }) => (
            <option key={label} value={index}>
              {label}
            </option>
          ))}
        </HeaderSelect>
        <HeaderSelect
          ariaLabel="Year"
          value={viewDate.year()}
          onChange={(value) => setViewYear(Number(value))}
        >
          {yearOptions.map((year) => (
            <option key={year} value={year}>
              {year}
            </option>
          ))}
        </HeaderSelect>
      </div>

      <NavButton
        ariaLabel="Next month"
        disabled={!isNextMonthAvailable}
        onClick={() => onChangeView((current) => current.add(1, 'month'))}
      >
        <ChevronRightIcon className="size-4" />
      </NavButton>
    </div>
  )
}

type NavButtonProps = {
  ariaLabel: string
  disabled: boolean
  onClick: () => void
  children: ReactNode
}

function NavButton({ ariaLabel, disabled, onClick, children }: NavButtonProps) {
  return (
    <button
      type="button"
      aria-label={ariaLabel}
      onClick={onClick}
      disabled={disabled}
      className="flex items-center justify-center size-7 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 disabled:opacity-40 disabled:hover:bg-transparent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500"
    >
      {children}
    </button>
  )
}

type HeaderSelectProps = {
  ariaLabel: string
  value: number
  onChange: (value: string) => void
  children: ReactNode
}

function HeaderSelect({
  ariaLabel,
  value,
  onChange,
  children
}: HeaderSelectProps) {
  return (
    <div className="relative">
      <select
        aria-label={ariaLabel}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="appearance-none bg-none pl-2.5 pr-7 py-1 text-sm font-medium rounded-md border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 hover:bg-gray-50 dark:hover:bg-gray-750 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 cursor-pointer"
      >
        {children}
      </select>
      <ChevronUpDownIcon
        aria-hidden="true"
        className="pointer-events-none absolute right-1.5 top-1/2 -translate-y-1/2 size-4 text-gray-500 dark:text-gray-400"
      />
    </div>
  )
}

type DayCellProps = {
  day: Dayjs
  viewMonth: number
  today: Dayjs
  focusedDate: Dayjs
  range: RangeBounds
  disabled: boolean
  focusRef?: Ref<HTMLButtonElement>
  onSelect: (day: Dayjs) => void
  onKeyDown: (event: KeyboardEvent<HTMLButtonElement>, day: Dayjs) => void
  onHover: (day: Dayjs) => void
}

function DayCell({
  day,
  viewMonth,
  today,
  focusedDate,
  range,
  disabled,
  focusRef,
  onSelect,
  onKeyDown,
  onHover
}: DayCellProps) {
  const inCurrentMonth = day.month() === viewMonth
  const isToday = day.isSame(today, 'day')
  const isFocused = day.isSame(focusedDate, 'day')

  const isRangeStart = !!range && day.isSame(range.from, 'day')
  const isRangeEnd = !!range && day.isSame(range.to, 'day')
  const isInRange =
    !!range && !day.isBefore(range.from, 'day') && !day.isAfter(range.to, 'day')
  const isInteriorRange = isInRange && !isRangeStart && !isRangeEnd
  const isSingleDayRange =
    !!range && range.from.isSame(range.to, 'day') && isRangeStart

  const isEndpoint = isRangeStart || isRangeEnd

  return (
    <div
      role="gridcell"
      className={classNames('flex items-center justify-center h-9', {
        'bg-indigo-50 dark:bg-indigo-500/15': isInRange && !isSingleDayRange,
        'rounded-l-md': isRangeStart && !isSingleDayRange,
        'rounded-r-md': isRangeEnd && !isSingleDayRange
      })}
    >
      <button
        type="button"
        ref={focusRef}
        tabIndex={isFocused ? 0 : -1}
        aria-label={ariaLabel(day)}
        aria-disabled={disabled || undefined}
        aria-current={isToday ? 'date' : undefined}
        aria-pressed={isEndpoint || undefined}
        data-today={isToday || undefined}
        data-outside-month={!inCurrentMonth || undefined}
        data-selected={isEndpoint || undefined}
        data-in-range={isInteriorRange || undefined}
        disabled={disabled}
        onClick={() => onSelect(day)}
        onKeyDown={(event) => onKeyDown(event, day)}
        onMouseEnter={() => onHover(day)}
        className={classNames(
          'relative flex items-center justify-center size-9 rounded-md text-sm font-medium transition-colors',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500',
          {
            'text-gray-900 dark:text-gray-100':
              inCurrentMonth && !disabled && !isEndpoint,
            'text-gray-400 dark:text-gray-500': !inCurrentMonth && !disabled,
            'text-gray-300 dark:text-gray-600 cursor-not-allowed': disabled,
            'hover:bg-gray-100 dark:hover:bg-gray-700':
              !disabled && !isEndpoint,
            'bg-indigo-600 text-white hover:bg-indigo-600 dark:bg-indigo-500 dark:hover:bg-indigo-500':
              isEndpoint && !disabled
          }
        )}
      >
        {day.date()}
        {isToday && (
          <span
            aria-hidden="true"
            className={classNames(
              'absolute bottom-1 left-1/2 -translate-x-1/2 size-1 rounded-full',
              isEndpoint ? 'bg-white' : 'bg-indigo-500 dark:bg-indigo-400'
            )}
          />
        )}
      </button>
    </div>
  )
}
