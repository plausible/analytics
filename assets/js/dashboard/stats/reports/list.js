import React from 'react';
import { Link } from 'react-router-dom'

import FadeIn from '../../fade-in'
import MoreLink from '../more-link'
import numberFormatter from '../../util/number-formatter'
import Bar from '../bar'
import LazyLoader from '../../components/lazy-loader'

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
    if (this.props.query.period === 'realtime') {
      return 'Current visitors'
    }

    if (this.showConversionRate()) {
      return 'Conversions'
    }

    return this.valueLabel()
  }

  showConversionRate() {
    return !!this.props.query.filters.goal
  }

  valueKey() {
    return this.props.valueKey || 'visitors'
  }

  valueLabel() {
    return this.props.valueLabel || 'Visitors'
  }

  renderExternalLink(item) {
    if (this.props.externalLinkDest) {
      const dest = this.props.externalLinkDest(item)

      return (
        <a
          target="_blank"
          rel="noreferrer"
          href={dest}
          className="hidden group-hover:block"
        >
          <svg className="inline w-4 h-4 ml-1 -mt-1 text-gray-600 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20"><path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z"></path><path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z"></path></svg>
        </a>
      )
    }
  }

  renderListItem(listItem) {
    const query = new URLSearchParams(window.location.search)

    Object.entries(this.props.filter).forEach((([key, valueKey]) => {
      query.set(key, listItem[valueKey])
    }))

    const maxWidthDeduction =  this.showConversionRate() ? "10rem" : "5rem"
    const lightBackground = this.props.color || 'bg-green-50'

    return (
      <div className="flex items-center justify-between my-1 text-sm" key={listItem.name}>
        <Bar
          count={listItem[this.valueKey()]}
          all={this.state.list}
          bg={`${lightBackground} dark:bg-gray-500 dark:bg-opacity-15`}
          maxWidthDeduction={maxWidthDeduction}
          plot={this.valueKey()}
        >
          <span className="flex px-2 py-1.5 group dark:text-gray-300 relative z-9 break-all" tooltip={this.props.tooltipText && this.props.tooltipText(listItem)}>
            <Link className="md:truncate block hover:underline" to={{search: query.toString()}}>
              {this.props.renderIcon && this.props.renderIcon(listItem)}
              {this.props.renderIcon && ' '}
              {listItem.name}
            </Link>
            { this.renderExternalLink(listItem) }
          </span>
        </Bar>
        <span className="font-medium dark:text-gray-200 w-20 text-right">
          {numberFormatter(listItem[this.valueKey()])}
          {
            listItem.percentage >= 0
              ? <span className="inline-block w-8 text-xs text-right">({listItem.percentage}%)</span>
              : null
          }
        </span>
        {this.showConversionRate() && <span className="font-medium dark:text-gray-200 w-20 text-right">{listItem.conversion_rate}%</span>}
      </div>
    )
  }

  renderList() {
    if (this.state.list && this.state.list.length > 0) {
      return (
        <>
          <div className="flex items-center justify-between mt-3 mb-2 text-xs font-bold tracking-wide text-gray-500 dark:text-gray-400">
            <span>{ this.props.keyLabel }</span>
            <span className="text-right">
              <span className="inline-block w-30">{this.label()}</span>
              {this.showConversionRate() && <span className="inline-block w-20">CR</span>}
            </span>
          </div>
          { this.state.list && this.state.list.map(this.renderListItem.bind(this)) }
        </>
      )
    }

    return <div className="font-medium text-center text-gray-500 mt-44 dark:text-gray-400">No data yet</div>
  }

  render() {
    return (
      <LazyLoader onVisible={this.onVisible} className="flex flex-col flex-grow">
        { this.state.loading && <div className="mx-auto loading mt-44"><div></div></div> }
        <FadeIn show={!this.state.loading} className="flex-grow">
          { this.renderList() }
        </FadeIn>
        {this.props.detailsLink && !this.state.loading && <MoreLink url={this.props.detailsLink} list={this.state.list} />}
      </LazyLoader>
    )
  }
}
