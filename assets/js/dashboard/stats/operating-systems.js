import React from 'react';

import Bar from './bar'
import MoreLink from './more-link'
import * as api from '../api'

export default class OperatingSystems extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    this.fetchOperatingSystems()
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, systems: null})
      this.fetchOperatingSystems()
    }
  }

  fetchOperatingSystems() {
    api.get(`/api/stats/${this.props.site.domain}/operating-systems`, this.props.query)
      .then((res) => this.setState({loading: false, systems: res}))
  }

  renderSystem(system) {
    return (
      <React.Fragment key={system.name}>
        <div className="flex items-center justify-between my-2">
          <span className="truncate" style={{maxWidth: '80%'}}>{system.name}</span>
          <span tooltip={`${system.count} visitors`}>{system.percentage}%</span>
        </div>
        <Bar count={system.count} all={this.state.systems} color="blue" />
      </React.Fragment>
    )
  }

  render() {
    if (this.state.loading) {
      return (
        <div className="w-full md:w-31percent bg-white shadow-md rounded mt-4 p-4" style={{height: '405px'}}>
          <div className="loading my-32 mx-auto"><div></div></div>
        </div>
      )
    } else if (this.state.systems) {
      return (
        <div className="w-full md:w-31percent bg-white shadow-md rounded mt-4 p-4" style={{height: '405px'}}>
          <div className="text-center">
            <h2>Operating Systems</h2>
            <div className="text-grey-darker mt-1">by visitors</div>
          </div>

          <div className="mt-8">
            { this.state.systems.map(this.renderSystem.bind(this)) }
          </div>
          <MoreLink site={this.props.site} list={this.state.systems} endpoint="operating-systems" />
        </div>
      )
    }
  }
}
