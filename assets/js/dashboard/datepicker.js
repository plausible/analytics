import React from 'react';
import { Link } from 'react-router-dom'
import {shiftDays, shiftMonths, formatDay, formatMonth, formatISO} from './date'

export default class DatePicker extends React.Component {
  timeFrameText() {
    const {query} = this.props

    if (query.period === 'day') {
      return formatDay(query.date)
    } else if (query.period === '7d') {
      return 'Last 7 days'
    } else if (query.period === 'month') {
      return formatMonth(query.date)
    } else if (query.period === '3mo') {
      return 'Last 3 months'
    } else if (query.period === '6mo') {
      return 'Last 6 months'
    }
  }

  renderArrow(period, prevDate, nextDate) {
    return (
      <div className="flex rounded shadow bg-white mr-4 cursor-pointer">
        <Link to={`/${this.props.site.domain}?period=${period}&date=${prevDate}`} className="flex items-center px-2 border-r border-grey-light">
          <svg className="fill-current h-4 w-4" style={{transform: 'translateY(-2px)'}}>
            <use xlinkHref="#feather-chevron-left" />
          </svg>
        </Link>
        <Link to={`/${this.props.site.domain}?period=${period}&date=${nextDate}`} className="flex items-center px-2">
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
          <a href={`/${this.props.site.domain}?period=day`} className="block p-2 hover:bg-grey-lighter">Today</a>
          <a href={`/${this.props.site.domain}?period=7d`} className="block p-2 hover:bg-grey-lighter">Last 7 days</a>
          <a href={`/${this.props.site.domain}?period=month`} className="block p-2 hover:bg-grey-lighter">This month</a>
          <a href={`/${this.props.site.domain}?period=3mo`} className="block p-2 hover:bg-grey-lighter">Last 3 months</a>
          <a href={`/${this.props.site.domain}?period=6mo`} className="block p-2 hover:bg-grey-lighter">Last 6 months</a>
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
