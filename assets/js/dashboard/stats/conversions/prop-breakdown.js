import React from 'react';
import { Link } from 'react-router-dom'

import Bar from '../bar'
import numberFormatter from '../../number-formatter'
import * as api from '../../api'

export default class PropertyBreakdown extends React.Component {
  constructor(props) {
    super(props)
    let propKey = props.goal.prop_names[0]
    this.storageKey = 'goalPropTab__' + props.site.domain + props.goal.name
    const storedKey = window.localStorage[this.storageKey]
    if (props.goal.prop_names.includes(storedKey)) {
      propKey = storedKey
    }
    if (props.query.filters['props']) {
      propKey = Object.keys(props.query.filters['props'])[0]
    }

    this.state = {
      loading: true,
      propKey: propKey
    }
  }

  componentDidMount() {
    this.fetchPropBreakdown()
  }

  fetchPropBreakdown() {
    if (this.props.query.filters['goal']) {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/property/${encodeURIComponent(this.state.propKey)}`, this.props.query)
        .then((res) => this.setState({loading: false, breakdown: res}))
    }
  }

  renderPropValue(value) {
    const query = new URLSearchParams(window.location.search)
    query.set('props', JSON.stringify({[this.state.propKey]: value.name}))

    return (
      <div className="flex items-center justify-between my-2" key={value.name}>
        <div className="w-full h-8 relative" style={{maxWidth: 'calc(100% - 16rem)'}}>
          <Bar count={value.count} all={this.state.breakdown} bg="bg-red-50" />
          <Link to={{search: query.toString()}} style={{marginTop: '-26px'}} className="hover:underline block px-2">
            { value.name }
          </Link>
        </div>
        <div>
          <span className="font-medium inline-block w-20 text-right">{numberFormatter(value.count)}</span>
          <span className="font-medium inline-block w-20 text-right">{numberFormatter(value.total_count)}</span>
          <span className="font-medium inline-block w-20 text-right">{numberFormatter(value.conversion_rate)}%</span>
        </div>
      </div>
    )
  }

  changePropKey(newKey) {
    window.localStorage[this.storageKey] = newKey
    this.setState({propKey: newKey, loading: true}, this.fetchPropBreakdown)
  }

  renderBody() {
    if (this.state.loading) {
      return <div className="px-4 py-2"><div className="loading sm mx-auto"><div></div></div></div>
    } else {
      return this.state.breakdown.map((propValue) => this.renderPropValue(propValue))
    }
  }

  renderPill(key) {
    const isActive = this.state.propKey === key

    if (isActive) {
      return <li key={key} className="inline-block h-5 text-indigo-700 font-bold border-b-2 border-indigo-700">{key}</li>
    } else {
      return <li key={key} className="hover:text-indigo-700 cursor-pointer" onClick={this.changePropKey.bind(this, key)}>{key}</li>
    }
  }

  render() {
    return (
      <div className="w-full pl-6 mt-4">
        <div className="flex items-center pb-1">
          <span className="text-xs font-bold text-gray-600">Breakdown by:</span>
          <ul className="flex font-medium text-xs text-gray-500 space-x-2 leading-5 pl-1">
            { this.props.goal.prop_names.map(this.renderPill.bind(this)) }
          </ul>
        </div>
        { this.renderBody() }
      </div>
    )
  }
}
