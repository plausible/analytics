import React from 'react';
import { withRouter, Link } from 'react-router-dom'
import Flatpickr from "react-flatpickr";
import {shiftDays, shiftMonths, formatDay, formatDayShort, formatMonthYYYY, formatISO, isToday} from './date'


class DatePicker extends React.Component {
  constructor(props) {
    super(props)
    this.handleKeyup = this.handleKeyup.bind(this)
    this.handleClick = this.handleClick.bind(this)
    this.state = {mode: 'closed'}
  }

  componentDidMount() {
    document.addEventListener('keyup', this.handleKeyup);
    document.addEventListener('mousedown', this.handleClick, false);
  }

  componentWillUnmount() {
    document.removeEventListener("keyup", this.handleKeyup);
    document.removeEventListener('mousedown', this.handleClick, false);
  }

  queryWithPeriod(period, dates) {
    const query = new URLSearchParams(window.location.search)
    query.set('period', period)
    query.delete('date'); query.delete('from'); query.delete('to')

    if (dates) {
      for (const key of Object.keys(dates)) {
        query.set(key, dates[key])
      }
    } else {
      query.delete('date')
    }

    return query.toString()
  }

  handleKeyup(e) {
    const {query, history} = this.props

    if (e.key === 'ArrowLeft') {
      if (query.period === 'day') {
        const prevDate = formatISO(shiftDays(query.date, -1))
        history.push({search: this.queryWithPeriod('day', {date: prevDate})})
      } else if (query.period === 'month') {
        const prevMonth = formatISO(shiftMonths(query.date, -1))
        history.push({search: this.queryWithPeriod('month', {date: prevMonth})})
      }
    } else if (e.key === 'ArrowRight') {
      if (query.period === 'day') {
        const nextDate = formatISO(shiftDays(query.date, 1))
        history.push({search: this.queryWithPeriod('day', {date: nextDate})})
      } else if (query.period === 'month') {
        const nextMonth = formatISO(shiftMonths(query.date, 1))
        history.push({search: this.queryWithPeriod('month', {date: nextMonth})})
      }
    }
  }

  handleClick(e) {
    if (this.dropDownNode && this.dropDownNode.contains(e.target)) return;

    this.setState({mode: 'closed'})
  }

  timeFrameText() {
    const {query, site} = this.props

    if (query.period === 'day') {
      if (isToday(site, query.date)) {
        return 'Today'
      } else {
        return formatDay(query.date)
      }
    } else if (query.period === '7d') {
      return 'Last 7 days'
    } else if (query.period === '30d') {
      return 'Last 30 days'
    } else if (query.period === '60d') {
      return 'Last 60 days'
    } else if (query.period === 'month') {
      return formatMonthYYYY(query.date)
    } else if (query.period === '6mo') {
      return 'Last 6 months'
    } else if (query.period === '12mo') {
      return 'Last 12 months'
    } else if (query.period === 'realtime') {
      return 'Real-time'
    } else if (query.period === 'custom') {
      return `${formatDayShort(query.from)} - ${formatDayShort(query.to)}`
    }
  }

  renderArrow(period, prevDate, nextDate) {
    return (
      <div className="flex rounded shadow bg-white mr-4 cursor-pointer">
        <Link to={{search: this.queryWithPeriod(period, {date: prevDate})}} className="flex items-center px-2 border-r border-gray-300">
          <svg className="fill-current h-4 w-4">
            <use xlinkHref="#feather-chevron-left" />
          </svg>
        </Link>
        <Link to={{search: this.queryWithPeriod(period, {date: nextDate})}} className="flex items-center px-2">
          <svg className="fill-current h-4 w-4">
            <use xlinkHref="#feather-chevron-right" />
          </svg>
        </Link>
      </div>
    )
  }

  renderArrows() {
    const {query} = this.props

    if (query.period === 'month') {
      const prevDate = formatISO(shiftMonths(query.date, -1))
      const nextDate = formatISO(shiftMonths(query.date, 1))

      return this.renderArrow('month', prevDate, nextDate)
    } else if (query.period === 'day') {
      const prevDate = formatISO(shiftDays(query.date, -1))
      const nextDate = formatISO(shiftDays(query.date, 1))

      return this.renderArrow('day', prevDate, nextDate)
    }
  }

  open() {
    this.setState({mode: 'open'})
  }

  renderDropDown() {
    return (
      <div className="relative z-50" style={{height: '35.5px', width: '190px'}}  ref={node => this.dropDownNode = node}>
        <div onClick={this.open.bind(this)} className="flex items-center justify-between rounded bg-white shadow px-4 pr-3 py-2 leading-tight cursor-pointer text-sm font-medium text-gray-800 h-full">
          <span className="mr-2">{this.timeFrameText()}</span>
          <svg className="text-pink-500 fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
            <use xlinkHref="#feather-chevron-down" />
          </svg>
        </div>

        {this.renderDropDownContent()}
      </div>
    )
  }

  close() {
    this.setState({mode: 'closed'})
  }

  renderLink(period, text) {
    const {query, site} = this.props
    let boldClass;
    if (query.period === 'day' && period === 'day') {
      boldClass = isToday(site, query.date) ? 'font-bold' : ''
    } else {
      boldClass = query.period === period ? 'font-bold' : ''
    }

    return (
      <Link to={{search: this.queryWithPeriod(period)}} onClick={this.close.bind(this)} className={boldClass + ' block px-4 py-2 text-sm leading-tight hover:bg-gray-100 hover:text-gray-900'}>
        {text}
      </Link>
    )
  }

  renderDropDownContent() {
    if (this.state.mode === 'open') {
      return (
        <div className="absolute mt-2 rounded shadow-md z-10" style={{width: '235px', right: '-14px'}}>
          <div className="rounded bg-white shadow-xs font-medium text-gray-800">
            <div className="py-1">
              { this.renderLink('day', 'Today') }
              { this.renderLink('realtime', 'Real-time') }
            </div>
            <div className="border-t border-gray-200"></div>
            <div className="py-1">
              { this.renderLink('7d', 'Last 7 days') }
              { this.renderLink('30d', 'Last 30 days') }
              { this.renderLink('60d', 'Last 60 days') }
            </div>
            <div className="border-t border-gray-200"></div>
            <div className="py-1">
              { this.renderLink('6mo', 'Last 6 months') }
              { this.renderLink('12mo', 'Last 12 months') }
            </div>
            <div className="border-t border-gray-200"></div>
            <div className="py-1">
              <span onClick={e => this.setState({mode: 'calendar'}, this.openCalendar.bind(this))} className="block px-4 py-2 text-sm leading-tight hover:bg-gray-100 hover:text-gray-900 cursor-pointer">Custom range</span>
            </div>
          </div>
        </div>
      )
    } else if (this.state.mode === 'calendar') {
      return <Flatpickr options={{mode: 'range', maxDate: 'today', showMonths: 1, static: true, animate: false}} ref={calendar => this.calendar = calendar} className="invisible" onChange={this.setCustomDate.bind(this)} />
    }
  }

  setCustomDate(dates) {
    if (dates.length === 2) {
      const [from, to] = dates
      this.props.history.push({search: this.queryWithPeriod('custom', {from: formatISO(from), to: formatISO(to)})})
    }
  }

  openCalendar() {
    this.calendar && this.calendar.flatpickr.open()
  }

  render() {
    return (
      <div className="flex justify-between sm:justify-between">
        { this.renderArrows() }
        { this.renderDropDown() }
      </div>
    )
  }
}

export default withRouter(DatePicker)
