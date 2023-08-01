import React from 'react';
import { Link } from 'react-router-dom'
import FlipMove from 'react-flip-move'

import Bar from '../bar'
import PropBreakdown from './prop-breakdown'
import numberFormatter from '../../util/number-formatter'
import * as api from '../../api'
import * as url from '../../util/url'
import { escapeFilterValue } from '../../util/filters'
import LazyLoader from '../../components/lazy-loader'
import Money from './money'

export default class DeprecatedConversions extends React.Component {
  constructor(props) {
    super(props)
    this.htmlNode = React.createRef()
    this.state = { loading: true, }
    this.onVisible = this.onVisible.bind(this)
    this.fetchConversions = this.fetchConversions.bind(this)
  }

  componentWillUnmount() {
    document.removeEventListener('tick', this.fetchConversions)
  }

  onVisible() {
    this.fetchConversions()
    if (this.props.query.period === 'realtime') {
      document.addEventListener('tick', this.fetchConversions)
    }
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      const height = this.htmlNode.current.offsetHeight
      this.setState({ loading: true, goals: null, prevHeight: height })
      this.fetchConversions()
    }
  }

  fetchConversions() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/conversions`, this.props.query, {limit: 100})
      .then((res) => this.setState({ loading: false, goals: res, prevHeight: null }))
  }

  renderGoal(goal, renderRevenueColumn) {
    const renderProps = this.props.query.filters['goal'] == goal.name && goal.prop_names

    return (
      <div className="my-2 text-sm" key={goal.name}>
        <div className="flex items-center justify-between my-2">
          <span className="flex-1">
            <Bar
              count={goal.visitors}
              all={this.state.goals}
              bg="bg-red-50 dark:bg-gray-500 dark:bg-opacity-15"
              plot="visitors"
            >
              <Link to={url.setQuery('goal', escapeFilterValue(goal.name))} className="block px-2 py-1.5 hover:underline relative z-9 break-all lg:truncate dark:text-gray-200">{goal.name}</Link>
            </Bar>
          </span>
          <div className="dark:text-gray-200">
            <span className="inline-block w-20 font-medium text-right">{numberFormatter(goal.visitors)}</span>
            <span className="hidden md:inline-block md:w-20 font-medium text-right">{numberFormatter(goal.events)}</span>
            <span className="inline-block w-20 font-medium text-right">{goal.conversion_rate}%</span>
            {renderRevenueColumn && <span className="hidden md:inline-block md:w-20 font-medium text-right"><Money formatted={goal.total_revenue} /></span>}
            {renderRevenueColumn && <span className="hidden md:inline-block md:w-20 font-medium text-right"><Money formatted={goal.average_revenue} /></span>}
          </div>
        </div>
        { renderProps && <PropBreakdown site={this.props.site} query={this.props.query} goal={goal} renderRevenueColumn={renderRevenueColumn } /> }
      </div>
    )
  }

  renderInner() {
    if (this.state.loading) {
      return <div className="mx-auto my-2 loading"><div></div></div>
    } else if (this.state.goals) {
      const hasRevenue = this.state.goals.some((goal) => goal.total_revenue)

      return (
        <React.Fragment>
          <div className="flex items-center justify-between mt-3 mb-2 text-xs font-bold tracking-wide text-gray-500 dark:text-gray-400">
            <span>Goal</span>
            <div className="text-right">
              <span className="inline-block w-20">Uniques</span>
              <span className="hidden md:inline-block md:w-20">Total</span>
              <span className="inline-block w-20">CR</span>
              {hasRevenue && <span className="hidden md:inline-block md:w-20">Revenue</span>}
              {hasRevenue && <span className="hidden md:inline-block md:w-20">Average</span>}
            </div>
          </div>
          <FlipMove>
            { this.state.goals.map((goal) => this.renderGoal.bind(this)(goal, hasRevenue) ) }
          </FlipMove>
        </React.Fragment>
      )
    }
  }

  renderConversions() {
    return (
      <div ref={this.htmlNode} style={{ minHeight: '132px', height: this.state.prevHeight ?? 'auto' }} >
        <LazyLoader onVisible={this.onVisible}>
          {this.renderInner()}
        </LazyLoader>
      </div>
    )
  }

  render() {
    return (
      <div>
        {this.renderConversions()}
      </div>
    )
  }
}
