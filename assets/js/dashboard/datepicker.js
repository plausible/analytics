import React, { Fragment, useState, useEffect, useCallback, useRef } from "react";
import { withRouter } from "react-router-dom";
import Flatpickr from "react-flatpickr";
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import { Transition } from '@headlessui/react'
import {
  shiftDays,
  shiftMonths,
  formatDay,
  formatMonthYYYY,
  formatYear,
  formatISO,
  isToday,
  lastMonth,
  nowForSite,
  isSameMonth,
  isThisMonth,
  isThisYear,
  parseUTCDate,
  parseNaiveDate,
  isBefore,
  isAfter,
  formatDateRange
} from "./util/date";
import { navigateToQuery, QueryLink, QueryButton } from "./query";
import { shouldIgnoreKeypress } from "./keybinding.js"
import { COMPARISON_DISABLED_PERIODS, toggleComparisons, isComparisonEnabled } from "../dashboard/comparison-input.js"
import classNames from "classnames"

function renderArrow(query, site, period, prevDate, nextDate) {
  const insertionDate = parseUTCDate(site.statsBegin);
  const disabledLeft = isBefore(
    parseUTCDate(prevDate),
    insertionDate,
    period
  );
  const disabledRight = isAfter(
    parseUTCDate(nextDate),
    nowForSite(site),
    period
  );

  const isComparing = isComparisonEnabled(query.comparison)

  const leftClass = classNames("flex items-center px-1 sm:px-2 border-r border-gray-300 rounded-l dark:border-gray-500 dark:text-gray-100", {
    "bg-gray-300 dark:bg-gray-950": disabledLeft,
    "hover:bg-gray-100 dark:hover:bg-gray-900": !disabledLeft,
  })

  const rightClass = classNames("flex items-center px-1 sm:px-2 rounded-r dark:text-gray-100", {
    "bg-gray-300 dark:bg-gray-950": disabledRight,
    "hover:bg-gray-100 dark:hover:bg-gray-900": !disabledRight,
  })

  const containerClass = classNames("rounded shadow bg-white mr-2 sm:mr-4 cursor-pointer dark:bg-gray-800", {
    "hidden md:flex": isComparing,
    "flex": !isComparing,
  })

  return (
    <div className={containerClass}>
      <QueryButton
        to={{ date: prevDate }}
        query={query}
        className={leftClass}
        disabled={disabledLeft}
      >
        <svg
          className="feather h-4 w-4"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <polyline points="15 18 9 12 15 6"></polyline>
        </svg>
      </QueryButton>
      <QueryButton
        to={{ date: nextDate }}
        query={query}
        className={rightClass}
        disabled={disabledRight}
      >
        <svg
          className="feather h-4 w-4"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <polyline points="9 18 15 12 9 6"></polyline>
        </svg>
      </QueryButton>
    </div>
  );
}

function DatePickerArrows({site, query}) {
  if (query.period === "year") {
    const prevDate = formatISO(shiftMonths(query.date, -12));
    const nextDate = formatISO(shiftMonths(query.date, 12));

    return renderArrow(query, site, "year", prevDate, nextDate);
  } else if (query.period === "month") {
    const prevDate = formatISO(shiftMonths(query.date, -1));
    const nextDate = formatISO(shiftMonths(query.date, 1));

    return renderArrow(query, site, "month", prevDate, nextDate);
  } else if (query.period === "day") {
    const prevDate = formatISO(shiftDays(query.date, -1));
    const nextDate = formatISO(shiftDays(query.date, 1));

    return renderArrow(query, site, "day", prevDate, nextDate);
  }

  return null
}

function DisplayPeriod({query, site}) {
  if (query.period === "day") {
    if (isToday(site, query.date)) {
      return "Today";
    }
    return formatDay(query.date);
  } if (query.period === '7d') {
    return 'Last 7 days'
  } if (query.period === '30d') {
    return 'Last 30 days'
  } if (query.period === 'month') {
    if (isThisMonth(site, query.date)) {
      return 'Month to Date'
    }
    return formatMonthYYYY(query.date)
  } if (query.period === '6mo') {
    return 'Last 6 months'
  } if (query.period === '12mo') {
    return 'Last 12 months'
  } if (query.period === 'year') {
    if (isThisYear(site, query.date)) {
      return 'Year to Date'
    }
    return formatYear(query.date)
  } if (query.period === 'all') {
    return 'All time'
  } if (query.period === 'custom') {
    return formatDateRange(site, query.from, query.to)
  }
  return 'Realtime'
}

function DatePicker({query, site, history}) {
  const [open, setOpen] = useState(false)
  const [mode, setMode] = useState('menu')
  const dropDownNode = useRef(null)
  const calendar = useRef(null)

  const handleKeydown = useCallback((e) => {
    if (shouldIgnoreKeypress(e)) return true

    const newSearch = {
      period: false,
      from: false,
      to: false,
      date: false
    };

    const insertionDate = parseUTCDate(site.statsBegin);

    if (e.key === "ArrowLeft") {
      const prevDate = formatISO(shiftDays(query.date, -1));
      const prevMonth = formatISO(shiftMonths(query.date, -1));
      const prevYear = formatISO(shiftMonths(query.date, -12));

      if (query.period === "day" && !isBefore(parseUTCDate(prevDate), insertionDate, query.period)) {
        newSearch.period = "day";
        newSearch.date = prevDate;
      } else if (query.period === "month" && !isBefore(parseUTCDate(prevMonth), insertionDate, query.period)) {
        newSearch.period = "month";
        newSearch.date = prevMonth;
      } else if (query.period === "year" && !isBefore(parseUTCDate(prevYear), insertionDate, query.period)) {
        newSearch.period = "year";
        newSearch.date = prevYear;
      }
    } else if (e.key === "ArrowRight") {
      const now = nowForSite(site)
      const nextDate = formatISO(shiftDays(query.date, 1));
      const nextMonth = formatISO(shiftMonths(query.date, 1));
      const nextYear = formatISO(shiftMonths(query.date, 12));

      if (query.period === "day" && !isAfter(parseUTCDate(nextDate), now, query.period)) {
        newSearch.period = "day";
        newSearch.date = nextDate;
      } else if (query.period === "month" && !isAfter(parseUTCDate(nextMonth), now, query.period)) {
        newSearch.period = "month";
        newSearch.date = nextMonth;
      } else if (query.period === "year" && !isAfter(parseUTCDate(nextYear), now, query.period)) {
        newSearch.period = "year";
        newSearch.date = nextYear;
      }
    }

    setOpen(false);

    const keybindings = {
      d: {date: false, period: 'day'},
      e: {date: formatISO(shiftDays(nowForSite(site), -1)), period: 'day'},
      r: {period: 'realtime'},
      w: {date: false, period: '7d'},
      m: {date: false, period: 'month'},
      y: {date: false, period: 'year'},
      t: {date: false, period: '30d'},
      s: {date: false, period: '6mo'},
      l: {date: false, period: '12mo'},
      a: {date: false, period: 'all'},
    }

    const redirect = keybindings[e.key.toLowerCase()]
    if (redirect) {
      navigateToQuery(history, query, {...newSearch, ...redirect})
    } else if (e.key.toLowerCase() === 'x') {
      toggleComparisons(history, query, site)
    } else if (e.key.toLowerCase() === 'c') {
      setOpen(true)
      setMode('calendar')
    } else if (newSearch.date) {
      navigateToQuery(history, query, newSearch);
    }
  }, [query])

  const handleClick = useCallback((e) => {
    if (dropDownNode.current && dropDownNode.current.contains(e.target)) return;

    setOpen(false)
  })

  useEffect(() => {
    if (mode === 'calendar' && open)   {
      openCalendar()
    }
  }, [mode])

  useEffect(() => {
    document.addEventListener("keydown", handleKeydown);
    return () => { document.removeEventListener("keydown", handleKeydown); }
  }, [handleKeydown])

  useEffect(() => {
    document.addEventListener("mousedown", handleClick, false);
    return () => { document.removeEventListener("mousedown", handleClick, false); }
  }, [])

  function setCustomDate([from, to], _dateStr, _instance) {
    if (from && to) {
      [from, to] = [parseNaiveDate(from), parseNaiveDate(to)]

      if (from.isSame(to)) {
        navigateToQuery( history, query, { period: 'day', date: formatISO(from), from: false, to: false })
      } else {
        navigateToQuery( history, query, { period: 'custom', date: false, from: formatISO(from), to: formatISO(to) })
      }
    }

    setOpen(false)
  }

  function toggle() {
    const newMode = mode === 'calendar' && !open ? 'menu' : mode
    setOpen(!open)
    setMode(newMode)
  }

  function openCalendar() {
    calendar.current && calendar.current.flatpickr.open();
  }

  function renderLink(period, text, opts = {}) {
    let boldClass;
    if (query.period === "day" && period === "day") {
      boldClass = isToday(site, query.date) ? "font-bold" : "";
    } else if (query.period === "month" && period === "month") {
      const linkDate = opts.date || nowForSite(site);
      boldClass = isSameMonth(linkDate, query.date) ? "font-bold" : "";
    } else {
      boldClass = query.period === period ? "font-bold" : "";
    }

    opts.date = opts.date ? formatISO(opts.date) : false;

    const keybinds = {
      'Today': 'D',
      'Realtime': 'R',
      'Last 7 days': 'W',
      'Month to Date': 'M',
      'Year to Date': 'Y',
      'Last 12 months': 'L',
      'Last 30 days': 'T',
      'All time': 'A',
    };

    return (
      <QueryLink
        to={{from: false, to: false, period, ...opts}}
        onClick={() => setOpen(false)}
        query={query}
        className={`${boldClass  } px-4 py-2 text-sm leading-tight hover:bg-gray-100 hover:text-gray-900
          dark:hover:bg-gray-900 dark:hover:text-gray-100 flex items-center justify-between`}
      >
        {text}
        <span className='font-normal'>{keybinds[text]}</span>
      </QueryLink>
    );
  }

  function renderDropDownContent() {
    if (mode === "menu") {
      return (
        <div
          id="datemenu"
          className="absolute w-full left-0 right-0 md:w-56 md:absolute md:top-auto md:left-auto md:right-0 mt-2 origin-top-right z-10"
        >
          <div
            className="rounded-md shadow-lg  bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5
            font-medium text-gray-800 dark:text-gray-200 date-options"
          >
            <div className="py-1 border-b border-gray-200 dark:border-gray-500 date-option-group">
              {renderLink("day", "Today")}
              {renderLink("realtime", "Realtime")}
            </div>
            <div className="py-1 border-b border-gray-200 dark:border-gray-500 date-option-group">
              {renderLink("7d", "Last 7 days")}
              {renderLink("30d", "Last 30 days")}
            </div>
            <div className="py-1 border-b border-gray-200 dark:border-gray-500 date-option-group">
              { renderLink('month', 'Month to Date') }
              { renderLink('month', 'Last month', {date: lastMonth(site)}) }
            </div>
            <div className="py-1 border-b border-gray-200 dark:border-gray-500 date-option-group">
              {renderLink("year", "Year to Date")}
              {renderLink("12mo", "Last 12 months")}
            </div>
            <div className="py-1 date-option-group">
              {renderLink("all", "All time")}
              <span
                onClick={() => setMode('calendar')}
                onKeyPress={() => setMode('calendar')}
                className="px-4 py-2 text-sm leading-tight hover:bg-gray-100
                  dark:hover:bg-gray-900 hover:text-gray-900 dark:hover:text-gray-100
                  cursor-pointer flex items-center justify-between"
                tabIndex="0"
                role="button"
                aria-haspopup="true"
                aria-expanded="false"
                aria-controls="calendar"
              >
                Custom range
                <span className='font-normal'>C</span>
              </span>
            </div>
            { !COMPARISON_DISABLED_PERIODS.includes(query.period) &&
              <div className="py-1 date-option-group border-t border-gray-200 dark:border-gray-500">
                <span
                  onClick={() => {
                    toggleComparisons(history, query, site)
                    setOpen(false)
                  }}
                  className="px-4 py-2 text-sm leading-tight hover:bg-gray-100 dark:hover:bg-gray-900 hover:text-gray-900 dark:hover:text-gray-100 cursor-pointer flex items-center justify-between">
                  { isComparisonEnabled(query.comparison) ? 'Disable comparison' : 'Compare' }
                  <span className='font-normal'>X</span>
                </span>
              </div> }
          </div>
        </div>
      );
    } if (mode === "calendar") {
      return (
        <div className="h-0">
          <Flatpickr
            id="calendar"
            options={{
              mode: 'range',
              maxDate: 'today',
              minDate: site.statsBegin,
              showMonths: 1,
              static: true,
              animate: true}}
            ref={calendar}
            className="invisible"
            onClose={setCustomDate}
          />
        </div>
      )
    }
  }

  function renderPicker() {
    return (
      <div
        className="min-w-32 md:w-48 md:relative"
        ref={dropDownNode}
      >
        <div
          onClick={toggle}
          className="flex items-center justify-between rounded bg-white dark:bg-gray-800 shadow px-2 md:px-3
          py-2 leading-tight cursor-pointer text-xs md:text-sm text-gray-800
          dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-900"
          tabIndex="0"
          role="button"
          aria-haspopup="true"
          aria-expanded="false"
          aria-controls="datemenu"
        >
          <span className="truncate mr-1 md:mr-2">
            <span className="font-medium"><DisplayPeriod query={query} site={site} /></span>
          </span>
          <ChevronDownIcon className="hidden sm:inline-block h-4 w-4 md:h-5 md:w-5 text-gray-500" />
        </div>

        <Transition
          show={open}
          as={Fragment}
          enter="transition ease-out duration-100"
          enterFrom="transform opacity-0 scale-95"
          enterTo="transform opacity-100 scale-100"
          leave="transition ease-in duration-75"
          leaveFrom="transform opacity-100 scale-100"
          leaveTo="transform opacity-0 scale-95"
        >
          {renderDropDownContent()}
        </Transition>
      </div>
    );
  }

  return (
    <div className="flex ml-auto pl-2">
      <DatePickerArrows site={site} query={query} />
      {renderPicker()}
    </div>
  )
}

export default withRouter(DatePicker);
