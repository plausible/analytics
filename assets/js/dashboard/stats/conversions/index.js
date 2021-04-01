import React from 'react';
import { Link } from 'react-router-dom'

import Bar from '../bar'
import MoreLink from '../more-link'
import PropBreakdown from './prop-breakdown'
import numberFormatter from '../../number-formatter'
import * as api from '../../api'
import LazyLoader from '../../lazy-loader'

export default class Conversions extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
    this.onVisible = this.onVisible.bind(this)
  }

  onVisible() {
    this.fetchConversions()
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, goals: null})
      this.fetchConversions()
    }
  }

  fetchConversions() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/conversions`, this.props.query)
      .then((res) => this.setState({loading: false, goals: res}))
  }

  renderGoalText(goalName) {
    if (this.props.query.period === 'realtime') {
      return <span className="block px-2" style={{marginTop: '-26px'}}>{goalName}</span>
    } else {
      const query = new URLSearchParams(window.location.search)
      query.set('goal', goalName)

      return (
        <Link to={{pathname: window.location.pathname, search: query.toString()}} style={{marginTop: '-26px'}} className="block px-2 hover:underline">
          { goalName }
        </Link>
      )
    }
  }

  renderGoal(goal) {
    const renderProps = this.props.query.filters['goal'] == goal.name && goal.prop_names

    return (
      <div className="my-2 text-sm" key={goal.name}>
        <div className="flex items-center justify-between my-2">
          <div className="relative w-full h-8 dark:text-gray-300" style={{maxWidth: 'calc(100% - 16rem)'}}>
            <Bar count={goal.count} all={this.state.goals} bg="bg-red-50 dark:bg-gray-500 dark:bg-opacity-15" />
            {this.renderGoalText(goal.name)}
          </div>
          <div className="dark:text-gray-200">
            <span className="inline-block w-20 font-medium text-right">{numberFormatter(goal.count)}</span>
            <span className="inline-block w-20 font-medium text-right">{numberFormatter(goal.total_count)}</span>
            <span className="inline-block w-20 font-medium text-right">{goal.conversion_rate}%</span>
          </div>
        </div>
        { renderProps && <PropBreakdown site={this.props.site} query={this.props.query} goal={goal} /> }
      </div>
    )
  }

  renderInner() {
    if (this.state.loading) {
      return <div className="mx-auto my-2 loading"><div></div></div>
    } else if (this.state.goals) {
      return (
        <React.Fragment>
          <h3 className="font-bold dark:text-gray-100">{this.props.title || "Goal Conversions"}</h3>
          <div className="flex items-center justify-between mt-3 mb-2 text-xs font-bold tracking-wide text-gray-500 dark:text-gray-400">
            <span>Goal</span>
            <div className="text-right">
              <span className="inline-block w-20">Uniques</span>
              <span className="inline-block w-20">Total</span>
              <span className="inline-block w-20">CR</span>
            </div>
          </div>

          { this.state.goals.map(this.renderGoal.bind(this)) }
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <LazyLoader className="w-full p-4 bg-white rounded shadow-xl dark:bg-gray-825" style={{minHeight: '94px'}} onVisible={this.onVisible}>
        { this.renderInner() }
      </LazyLoader>
    )
  }
}
