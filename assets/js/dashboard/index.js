import React from 'react';

import {parseQueryString} from './query-string'
import Datepicker from './datepicker'
import VisitorGraph from './stats/visitor-graph'
import Referrers from './stats/referrers'
import Pages from './stats/pages'
import Countries from './stats/countries'
import Browsers from './stats/browsers'
import OperatingSystems from './stats/operating-systems'
import ScreenSizes from './stats/screen-sizes'
import Conversions from './stats/conversions'

const PERIODS = ['day', 'month', '7d', '3mo', '6mo']

function parseQuery(querystring, siteDomain) {
  let {period, date} = parseQueryString(querystring)
  const periodKey = 'period__' + siteDomain

  if (PERIODS.includes(period)) {
    window.localStorage[periodKey] = period
  } else {
    if (window.localStorage[periodKey]) {
      period = window.localStorage[periodKey]
    } else {
      period = '6mo'
    }
  }

  return {
    period: period,
    date: date ? new Date(date) : new Date()
  }
}

export default class Stats extends React.Component {
  constructor(props) {
    super(props)
    const query = parseQuery(window.location.search, this.props.site.domain)
    this.state = {query: query}
  }

  renderConversions() {
    if (this.props.site.hasGoals) {
      return (
        <div className="w-full block md:flex items-start justify-between mt-6">
          <Conversions site={this.props.site} query={this.state.query} />
        </div>
      )
    }
  }

  render() {
    return (
      <div className="mb-12">
        <div className="w-full sm:flex justify-between items-center">
          <div className="w-full flex items-center">
            <h2 className="text-left mr-8">Analytics for <a href="//{this.props.domain}" target="_blank">{this.props.site.domain}</a></h2>
            <div className="text-sm font-bold text-grey-darker mt-2 mt-0">
              <svg className="w-2 mr-1 fill-current text-green" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
                <circle cx="8" cy="8" r="8"/>
              </svg>
              <span> 4</span> current visitors
            </div>
          </div>
          <Datepicker site={this.props.site} query={this.state.query} />
        </div>
        <VisitorGraph site={this.props.site} query={this.state.query} />
        <div className="w-full block md:flex items-start justify-between mt-6">
          <Referrers site={this.props.site} query={this.state.query} />
          <Pages site={this.props.site} query={this.state.query} />
          <Countries site={this.props.site} query={this.state.query} />
        </div>
        <div className="w-full block md:flex items-start justify-between mt-6">
          <Browsers site={this.props.site} query={this.state.query} />
          <OperatingSystems site={this.props.site} query={this.state.query} />
          <ScreenSizes site={this.props.site} query={this.state.query} />
        </div>

        { this.renderConversions() }
      </div>
    )
  }
}
