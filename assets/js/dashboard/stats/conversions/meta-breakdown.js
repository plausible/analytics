import React from 'react';
import { Link } from 'react-router-dom'

import Bar from '../bar'
import numberFormatter from '../../number-formatter'
import * as api from '../../api'

export default class MetaBreakdown extends React.Component {
  constructor(props) {
    super(props)
    let metaKey = props.goal.meta_keys[0]
    this.storageKey = 'goalMetaTab__' + props.site.domain + props.goal.name
    const storedKey = window.localStorage[this.storageKey]
    if (props.goal.meta_keys.includes(storedKey)) {
      metaKey = storedKey
    }
    if (props.query.filters['meta']) {
      metaKey = Object.keys(props.query.filters['meta'])[0]
    }

    this.state = {
      loading: true,
      metaKey: metaKey
    }
  }

  componentDidMount() {
    this.fetchMetaBreakdown()
  }

  fetchMetaBreakdown() {
    if (this.props.query.filters['goal']) {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/meta-breakdown/${encodeURIComponent(this.state.metaKey)}`, this.props.query)
        .then((res) => this.setState({loading: false, breakdown: res}))
    }
  }

  renderMetadataValue(value) {
    const query = new URLSearchParams(window.location.search)
    query.set('meta', JSON.stringify({[this.state.metaKey]: value.name}))

    return (
      <div className="flex items-center justify-between my-2" key={value.name}>
        <div className="w-full h-8 relative" style={{maxWidth: 'calc(100% - 10rem)'}}>
          <Bar count={value.count} all={this.state.breakdown} bg="bg-red-50" />
          <Link to={{search: query.toString()}} style={{marginTop: '-26px'}} className="hover:underline block px-2">
            { value.name }
          </Link>
        </div>
        <div>
          <span className="font-medium inline-block w-20 text-right">{numberFormatter(value.count)}</span>
          <span className="font-medium inline-block w-20 text-right">{numberFormatter(value.total_count)}</span>
        </div>
      </div>
    )
  }

  changeMetaKey(newKey) {
    window.localStorage[this.storageKey] = newKey
    this.setState({metaKey: newKey, loading: true}, this.fetchMetaBreakdown)
  }

  renderBody() {
    if (this.state.loading) {
      return <div className="px-4 py-2"><div className="loading sm mx-auto"><div></div></div></div>
    } else {
      return this.state.breakdown.map((metaValue) => this.renderMetadataValue(metaValue))
    }
  }

  renderPill(key) {
    const isActive = this.state.metaKey === key

    if (isActive) {
      return <li key={key} className="inline-block h-5 text-indigo-700 font-bold border-b-2 border-indigo-700">{key}</li>
    } else {
      return <li key={key} className="hover:text-indigo-700 cursor-pointer" onClick={this.changeMetaKey.bind(this, key)}>{key}</li>
    }
  }

  render() {
    return (
      <div className="w-full pl-6 mt-4">
        <div className="flex items-center pb-1">
          <span className="text-xs font-bold text-gray-600">Breakdown by:</span>
          <ul className="flex font-medium text-xs text-gray-500 space-x-2 leading-5 pl-1">
            { this.props.goal.meta_keys.map(this.renderPill.bind(this)) }
          </ul>
        </div>
        { this.renderBody() }
      </div>
    )
  }
}
