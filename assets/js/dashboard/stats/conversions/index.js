import React from 'react';
import { Link } from 'react-router-dom'

import Bar from '../bar'
import MoreLink from '../more-link'
import MetaBreakdown from './meta-breakdown'
import numberFormatter from '../../number-formatter'
import * as api from '../../api'

export default class Conversions extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
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
        <Link to={{search: query.toString()}} style={{marginTop: '-26px'}} className="hover:underline block px-2">
          { goalName }
        </Link>
      )
    }
  }

  renderGoal(goal) {
    const renderMeta = this.props.query.filters['goal'] == goal.name && goal.meta_keys

    return (
      <div className="my-2 text-sm" key={goal.name}>
        <div className="flex items-center justify-between my-2">
          <div className="w-full h-8 relative" style={{maxWidth: 'calc(100% - 10rem)'}}>
            <Bar count={goal.count} all={this.state.goals} bg="bg-red-50" />
            {this.renderGoalText(goal.name)}
          </div>
          <div>
            <span className="font-medium inline-block w-20 text-right">{numberFormatter(goal.count)}</span>
            <span className="font-medium inline-block w-20 text-right">{numberFormatter(goal.total_count)}</span>
          </div>
        </div>
        { renderMeta && <MetaBreakdown site={this.props.site} query={this.props.query} goal={goal} /> }
      </div>
    )
  }

  render() {
    if (this.state.loading) {
      return (
        <div className="w-full bg-white shadow-xl rounded p-4" style={{height: '94px'}}>
          <div className="loading my-2 mx-auto"><div></div></div>
        </div>
      )
    } else if (this.state.goals) {
      return (
        <div className="w-full bg-white shadow-xl rounded p-4">
          <h3 className="font-bold">{this.props.title || "Goal Conversions"}</h3>
          <div className="flex items-center mt-3 mb-2 justify-between text-gray-500 text-xs font-bold tracking-wide">
            <span>Goal</span>
            <div className="text-right">
              <span className="inline-block w-20">Uniques</span>
              <span className="inline-block w-20">Total</span>
            </div>
          </div>

          { this.state.goals.map(this.renderGoal.bind(this)) }
        </div>
      )
    }
  }
}
