import React from "react";
import { withRouter } from "react-router-dom";
import Flatpickr from "react-flatpickr";
import classNames from 'classnames'
import { ChevronDownIcon } from '@heroicons/react/solid'
import {
  shiftDays,
  shiftMonths,
  formatDay,
  formatDayShort,
  formatMonthYYYY,
  formatISO,
  isToday,
  lastMonth,
  nowForSite,
  isSameMonth,
  isThisMonth,
  parseUTCDate,
  isBefore,
  isAfter,
} from "./date";
import Transition from "../transition";
import { navigateToQuery, QueryLink, QueryButton } from "./query";

class DatePicker extends React.Component {
  constructor(props) {
    super(props);
    this.handleKeydown = this.handleKeydown.bind(this);
    this.handleClick = this.handleClick.bind(this);
    this.openCalendar = this.openCalendar.bind(this);
    this.open = this.open.bind(this);
    this.state = { mode: "menu", open: false };
  }

  componentDidMount() {
    document.addEventListener("keydown", this.handleKeydown);
    document.addEventListener("mousedown", this.handleClick, false);
  }

  componentWillUnmount() {
    document.removeEventListener("keydown", this.handleKeydown);
    document.removeEventListener("mousedown", this.handleClick, false);
  }

  handleKeydown(e) {
    const { query, history } = this.props;

    if (e.target.tagName === 'INPUT') return true;
    if (e.ctrlKey || e.metaKey || e.altKey || e.isComposing || e.keyCode === 229) return;

    const newSearch = {
      period: false,
      from: false,
      to: false,
      date: false,
    };

    const insertionDate = parseUTCDate(this.props.site.insertedAt);

    if (e.key === "ArrowLeft") {
      const prevDate = formatISO(shiftDays(query.date, -1));
      const prevMonth = formatISO(shiftMonths(query.date, -1));

      if (
        query.period === "day" &&
        !isBefore(parseUTCDate(prevDate), insertionDate, query.period)
      ) {
        newSearch.period = "day";
        newSearch.date = prevDate;
      } else if (
        query.period === "month" &&
        !isBefore(parseUTCDate(prevMonth), insertionDate, query.period)
      ) {
        newSearch.period = "month";
        newSearch.date = prevMonth;
      }
    } else if (e.key === "ArrowRight") {
      const nextDate = formatISO(shiftDays(query.date, 1));
      const nextMonth = formatISO(shiftMonths(query.date, 1));

      if (
        query.period === "day" &&
        !isAfter(
          parseUTCDate(nextDate),
          nowForSite(this.props.site),
          query.period
        )
      ) {
        newSearch.period = "day";
        newSearch.date = nextDate;
      } else if (
        query.period === "month" &&
        !isAfter(
          parseUTCDate(nextMonth),
          nowForSite(this.props.site),
          query.period
        )
      ) {
        newSearch.period = "month";
        newSearch.date = nextMonth;
      }
    }

    this.setState({open: false});

    const keys = ['d', 'r', 'w', 'm', 'y', 't', 's'];
    const redirects = [{date: false, period: 'day'}, {period: 'realtime'}, {date: false, period: '7d'}, {date: false, period: 'month'}, {date: false, period: '12mo'}, {date: false, period: '30d'}, {date: false, period: '6mo'}];

    if (keys.includes(e.key.toLowerCase())) {
      navigateToQuery(history, query, {...newSearch, ...(redirects[keys.indexOf(e.key.toLowerCase())])});
    } else if (e.key.toLowerCase() === 'f') {
      return history.push({pathname: `/${encodeURIComponent(this.props.site.domain)}/filter`, search: window.location.search})
    } else if (e.key.toLowerCase() === 'c') {
      this.setState({mode: 'calendar', open: true}, this.openCalendar);
    } else if (newSearch.date) {
      navigateToQuery(history, query, newSearch);
    }
  }

  handleClick(e) {
    if (this.dropDownNode && this.dropDownNode.contains(e.target)) return;

    this.setState({ open: false });
  }

  timeFrameText() {
    const { query, site } = this.props;

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
    } if (query.period === 'custom') {
      return `${formatDayShort(query.from)} - ${formatDayShort(query.to)}`
    }
    return 'Realtime'
  }

  open() {
    this.setState({ mode: "menu", open: true });
  }

  close() {
    this.setState({ open: false });
  }

  renderLink(period, text, opts = {}) {
    const { query, site } = this.props;
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
      'Last 12 months': 'Y',
      'Last 6 months': 'S',
      'Last 30 days': 'T',
    };

    return (
      <QueryLink
        to={{from: false, to: false, period, ...opts}}
        onClick={this.close.bind(this)}
        query={this.props.query}
        className={`${boldClass  } px-4 py-2 md:text-sm leading-tight hover:bg-gray-200
          dark:hover:bg-gray-900 hover:text-gray-900 dark:hover:text-gray-100 flex items-center justify-between`}
      >
        {text}
        <span className='font-normal'>{keybinds[text]}</span>
      </QueryLink>
    );
  }

  renderDropDownContent() {
    if (this.state.mode === "menu") {
      return (
        <div
          id="datemenu"
          className="absolute mt-2 rounded shadow-md z-10"
          style={{width: '235px', right: '-5px'}}
        >
          <div
            className="rounded bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5
            font-medium text-gray-800 dark:text-gray-200"
          >
            <div className="py-1">
              {this.renderLink("day", "Today")}
              {this.renderLink("realtime", "Realtime")}
            </div>
            <div className="border-t border-gray-200 dark:border-gray-500"></div>
            <div className="py-1">
              {this.renderLink("7d", "Last 7 days")}
              {this.renderLink("30d", "Last 30 days")}
            </div>
            <div className="border-t border-gray-200 dark:border-gray-500"></div>
            <div className="py-1">
              { this.renderLink('month', 'Month to Date') }
              { this.renderLink('month', 'Last month', {date: lastMonth(this.props.site)}) }
            </div>
            <div className="border-t border-gray-200 dark:border-gray-500"></div>
            <div className="py-1">
              {this.renderLink("6mo", "Last 6 months")}
              {this.renderLink("12mo", "Last 12 months")}
            </div>
            <div className="border-t border-gray-200 dark:border-gray-500"></div>
            <div className="py-1">
              <span
                onClick={() => this.setState({mode: 'calendar'}, this.openCalendar)}
                onKeyPress={() => this.setState({mode: 'calendar'}, this.openCalendar)}
                className="px-4 py-2 md:text-sm leading-tight hover:bg-gray-100
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
          </div>
        </div>
      );
    } if (this.state.mode === "calendar") {
      const insertionDate = new Date(this.props.site.insertedAt);
      const dayBeforeCreation = insertionDate - 86400000;
      return (
        <Flatpickr
          id="calendar"
          options={{
            mode: 'range',
            maxDate: 'today',
            minDate: dayBeforeCreation,
            showMonths: 1,
            static: true,
            animate: true}}
          ref={calendar => this.calendar = calendar}
          className="invisible"
          onChange={this.setCustomDate.bind(this)}
        />
        )
    }
  }

  setCustomDate(dates) {
    if (dates.length === 2) {
      const [from, to] = dates
      if (formatISO(from) === formatISO(to)) {
        navigateToQuery(
          this.props.history,
          this.props.query,
          {
            period: 'day',
            date: formatISO(from),
            from: false,
            to: false,
          }
        )
      } else {
        navigateToQuery(
          this.props.history,
          this.props.query,
          {
            period: 'custom',
            date: false,
            from: formatISO(from),
            to: formatISO(to),
          }
        )
      }
      this.close()
    }
  }

  openCalendar() {
    this.calendar && this.calendar.flatpickr.open();
  }

  render() {
    return (
      <div
        className={classNames('relative', this.props.className)}
        ref={(node) => (this.dropDownNode = node)}
      >
        <div
          onClick={this.open}
          onKeyPress={this.open}
          className="flex items-center justify-between rounded bg-white dark:bg-gray-800 shadow px-3
          py-2 leading-tight cursor-pointer text-xs md:text-sm text-gray-800
          dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-900"
          tabIndex="0"
          role="button"
          aria-haspopup="true"
          aria-expanded="false"
          aria-controls="datemenu"
        >
          <span className="mr-2">
            {this.props.leadingText}
            <span className="font-medium">{this.timeFrameText()}</span>
          </span>
          <ChevronDownIcon className="h-4 w-4 md:h-5 md:w-5 text-gray-500" />
        </div>

        <Transition
          show={this.state.open}
          enter="transition ease-out duration-100 transform"
          enterFrom="opacity-0 scale-95"
          enterTo="opacity-100 scale-100"
          leave="transition ease-in duration-75 transform"
          leaveFrom="opacity-100 scale-100"
          leaveTo="opacity-0 scale-95"
        >
          {this.renderDropDownContent()}
        </Transition>
      </div>
    );
  }
}

export default withRouter(DatePicker);
