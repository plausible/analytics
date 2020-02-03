import React from 'react';
import { Link } from 'react-router-dom'

import Bar from './bar'
import MoreLink from './more-link'
import numberFormatter from '../number-formatter'
import * as api from '../api'

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

  renderGoal(goal) {
    const query = new URLSearchParams(window.location.search)
    query.set('goal', goal.name)

    return (
      <React.Fragment key={goal.name}>
        <div className="flex items-center justify-between my-2">
          <Link to={{search: query.toString(), state: {scrollTop: true}}} className="truncate hover:underline" style={{maxWidth: '80%'}}>{ goal.name }</Link>
          <span>{numberFormatter(goal.count)}</span>
        </div>
        <Bar count={goal.count} all={this.state.goals} color="indigo" />
      </React.Fragment>
    )
  }

  render() {
    if (this.state.loading) {
      return (
        <div className="w-full md:w-31percent bg-white shadow-md rounded mt-4 p-4">
          <div className="loading my-32 mx-auto"><div></div></div>
        </div>
      )
    } else if (this.state.goals) {
      return (
        <div className="w-full md:w-31percent bg-white shadow-md rounded mt-4 p-4">
          <div className="text-center">
            <h2>Goal Conversions</h2>
            <div className="text-grey-darker mt-1">by visitors</div>
          </div>

          <div className="mt-8">
            { this.state.goals.map(this.renderGoal.bind(this)) }
          </div>
        </div>
      )
    }
  }
}
