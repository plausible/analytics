import React from 'react';
import { Link } from 'react-router-dom'

import FadeIn from '../../fade-in'
import numberFormatter from '../../number-formatter'
import Bar from '../bar'
import * as api from '../../api'
import * as url from '../../url'
import LazyLoader from '../../lazy-loader'

export default class OperatingSystems extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
    this.onVisible = this.onVisible.bind(this)
  }

  onVisible() {
    this.fetchOperatingSystems()
    if (this.props.timer) this.props.timer.onTick(this.fetchOperatingSystems.bind(this))
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, operatingSystems: null})
      this.fetchOperatingSystems()
    }
  }

  fetchOperatingSystems() {
    if (this.props.query.filters.os) {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/operating-system-versions`, this.props.query)
        .then((res) => this.setState({loading: false, operatingSystems: res}))
    } else {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/operating-systems`, this.props.query)
        .then((res) => this.setState({loading: false, operatingSystems: res}))
    }
  }

  showConversionRate() {
    return !!this.props.query.filters.goal
  }

  renderOperatingSystem(os) {
    let link;
    if (this.props.query.filters.os) {
      link = url.setQuery('os_version', os.name)
    } else {
      link = url.setQuery('os', os.name)
    }
    const maxWidthDeduction =  this.showConversionRate() ? "10rem" : "5rem"

    return (
      <div
        className="flex items-center justify-between my-1 text-sm"
        key={os.name}
      >
        <Bar
          count={os.count}
          all={this.state.operatingSystems}
          bg="bg-green-50 dark:gray-500 dark:bg-opacity-15"
          maxWidthDeduction={maxWidthDeduction}
        >
          <span className="flex px-2 py-1.5 dark:text-gray-300 relative z-9 break-all">
            <Link className="md:truncate block hover:underline" to={link}>
              {os.name}
            </Link>
          </span>
        </Bar>
        <span className="font-medium dark:text-gray-200 text-right w-20">{numberFormatter(os.count)} <span className="inline-block w-8 text-xs text-right">({os.percentage}%)</span></span>
        {this.showConversionRate() && <span className="font-medium dark:text-gray-200 w-20 text-right">{numberFormatter(os.conversion_rate)}%</span>}
      </div>
    )
  }

  label() {
    return this.props.query.period === 'realtime' ? 'Current visitors' : 'Visitors'
  }

  renderList() {
    const key = this.props.query.filters.os ? this.props.query.filters.os + ' version' : 'Operating system'

    if (this.state.operatingSystems && this.state.operatingSystems.length > 0) {
      return (
        <React.Fragment>
          <div className="flex items-center justify-between mt-3 mb-2 text-xs font-bold tracking-wide text-gray-500 dark:text-gray-400">
            <span>{ key }</span>
            <div className="text-right">
              <span className="inline-block w-20">{ this.label() }</span>
              {this.showConversionRate() && <span className="inline-block w-20">CR</span>}
            </div>
          </div>
          { this.state.operatingSystems && this.state.operatingSystems.map(this.renderOperatingSystem.bind(this)) }
        </React.Fragment>
      )
    } else {
      return <div className="font-medium text-center text-gray-500 mt-44 dark:text-gray-400">No data yet</div>
    }
  }

  render() {
    return (
      <LazyLoader onVisible={this.onVisible} className="flex flex-col flex-grow">
        { this.state.loading && <div className="mx-auto loading mt-44"><div></div></div> }
        <FadeIn show={!this.state.loading} className="flex-grow">
          { this.renderList() }
        </FadeIn>
      </LazyLoader>
    )
  }
}
