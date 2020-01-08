import React from 'react';
import { withRouter } from 'react-router-dom'
import { Link } from 'react-router-dom'
import {shiftDays, shiftMonths, formatDay, formatMonthYYYY, formatISO, isToday} from './date'

class DatePicker extends React.Component {
  constructor(props) {
    super(props)
    this.handleKeyup = this.handleKeyup.bind(this)
  }

  componentDidMount() {
    document.addEventListener("keyup", this.handleKeyup);
  }

  componentWillUnmount() {
    document.removeEventListener("keyup", this.handleKeyup);
  }

  queryWithPeriod(period, date) {
    const query = new URLSearchParams(window.location.search)
    query.set('period', period)

    if (date) {
      query.set('date', date)
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
        history.push({search: this.queryWithPeriod('day', prevDate)})
      } else if (query.period === 'month') {
        const prevMonth = formatISO(shiftMonths(query.date, -1))
        history.push({search: this.queryWithPeriod('month', prevMonth)})
      }
    } else if (e.key === 'ArrowRight') {
      if (query.period === 'day') {
        const nextDate = formatISO(shiftDays(query.date, 1))
        history.push({search: this.queryWithPeriod('day', nextDate)})
      } else if (query.period === 'month') {
        const nextMonth = formatISO(shiftMonths(query.date, 1))
        history.push({search: this.queryWithPeriod('month', nextMonth)})
      }
    }
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
    }
  }

  renderArrow(period, prevDate, nextDate) {
    return (
      <div className="flex rounded shadow bg-white mr-4 cursor-pointer">
        <Link to={{search: this.queryWithPeriod(period, prevDate)}} className="flex items-center px-2 border-r border-grey-light">
          <svg className="fill-current h-4 w-4" style={{transform: 'translateY(-2px)'}}>
            <use xlinkHref="#feather-chevron-left" />
          </svg>
        </Link>
        <Link to={{search: this.queryWithPeriod(period, nextDate)}} className="flex items-center px-2">
          <svg className="fill-current h-4 w-4" style={{transform: 'translateY(-2px)'}}>
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

  renderDropDown() {
    return (
      <div className="relative" style={{height: '35.5px', width: '190px'}}>
        <div data-dropdown-trigger className="flex items-center justify-between hover:bg-grey-lighter rounded bg-white shadow px-4 pr-3 py-2 leading-tight cursor-pointer text-sm font-bold text-grey-darker h-full">
          <span className="mr-2">{this.timeFrameText()}</span>
          <svg className="text-pink fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
            <use xlinkHref="#feather-chevron-down" />
          </svg>
        </div>

        <div data-dropdown style={{top: '42px', right: '0px', width: '225px'}} className="dropdown-content hidden absolute pin-r bg-white border border-grey-light rounded shadow z-10 font-bold text-sm text-grey-darker">
          <Link to={{search: this.queryWithPeriod('day')}} className="block p-2 hover:bg-grey-lighter">Today</Link>
          <Link to={{search: this.queryWithPeriod('7d')}} className="block p-2 hover:bg-grey-lighter">Last 7 days</Link>
          <Link to={{search: this.queryWithPeriod('30d')}} className="block p-2 hover:bg-grey-lighter">Last 30 days</Link>
          <Link to={{search: this.queryWithPeriod('60d')}} className="block p-2 hover:bg-grey-lighter">Last 60 days</Link>
          <Link to={{search: this.queryWithPeriod('6mo')}} className="block p-2 hover:bg-grey-lighter">Last 6 months</Link>
          <Link to={{search: this.queryWithPeriod('12mo')}} className="block p-2 hover:bg-grey-lighter">Last 12 months</Link>
        </div>
      </div>
    )
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
