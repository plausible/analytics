import React from 'react';
import { Link } from 'react-router-dom'

import FadeIn from '../../fade-in'
import numberFormatter from '../../number-formatter'
import Bar from '../bar'
import LazyLoader from '../../lazy-loader'

export default class ListReport extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
    this.onVisible = this.onVisible.bind(this)
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.fetchData()
    }
  }

  onVisible() {
    this.fetchData()
    if (this.props.timer) this.props.timer.onTick(this.fetchData.bind(this))
  }

  fetchData() {
    this.setState({loading: true, list: null})
    this.props.fetchData()
      .then((res) => this.setState({loading: false, list: res}))
  }

  label() {
    return this.props.query.period === 'realtime' ? 'Current visitors' : 'Visitors'
  }

  renderListItem(listItem) {
    const query = new URLSearchParams(window.location.search)

    Object.entries(this.props.filter).forEach((([key, valueKey]) => {
      query.set(key, listItem[valueKey])
    }))

    return (
      <div className="flex items-center justify-between my-1 text-sm" key={listItem.name}>
        <Bar
          count={listItem.count}
          all={this.state.list}
          bg="bg-green-50 dark:bg-gray-500 dark:bg-opacity-15"
          maxWidthDeduction="6rem"
        >
          <span className="flex px-2 py-1.5 dark:text-gray-300 relative z-9 break-all">
            <Link className="md:truncate block hover:underline" to={{search: query.toString()}}>
              {listItem.name}
            </Link>
          </span>
        </Bar>
        <span className="font-medium dark:text-gray-200">
          {numberFormatter(listItem.count)}
          {
            listItem.percentage &&
              <span className="inline-block w-8 text-xs text-right">({listItem.percentage}%)</span>
          }
        </span>
      </div>
    )
  }

  renderList() {
    if (this.state.list && this.state.list.length > 0) {
      return (
        <>
          <div className="flex items-center justify-between mt-3 mb-2 text-xs font-bold tracking-wide text-gray-500 dark:text-gray-400">
            <span>{ this.props.keyLabel }</span>
            <span>{ this.label() }</span>
          </div>
          { this.state.list && this.state.list.map(this.renderListItem.bind(this)) }
        </>
      )
    }

    return <div className="font-medium text-center text-gray-500 mt-44 dark:text-gray-400">No data yet</div>
  }

  render() {
    return (
      <div className="relative p-4 bg-white rounded shadow-xl stats-item flex flex-col dark:bg-gray-825 mt-6 w-full">
        <LazyLoader onVisible={this.onVisible} className="flex flex-col flex-grow">
          <h3 className="font-bold dark:text-gray-100">{this.props.title}</h3>
          { this.state.loading && <div className="mx-auto loading mt-44"><div></div></div> }
          <FadeIn show={!this.state.loading} className="flex-grow">
            { this.renderList() }
          </FadeIn>
        </LazyLoader>
      </div>
    )
  }
}

