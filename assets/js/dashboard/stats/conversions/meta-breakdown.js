import React from 'react';
import { Link } from 'react-router-dom'

import Transition from "../../../transition.js";
import Bar from '../bar'
import numberFormatter from '../../number-formatter'
import * as api from '../../api'

export default class MetaBreakdown extends React.Component {
  constructor(props) {
    super(props)
    this.handleClick = this.handleClick.bind(this)
    const metaFilter = props.query.filters['meta']
    console.log(metaFilter)
    const metaKey = metaFilter ? Object.keys(metaFilter)[0] : props.goal.meta_keys[0]
    this.state = {
      loading: true,
      dropdownOpen: false,
      metaKey: metaKey
    }
  }

  componentDidMount() {
    this.fetchMetaBreakdown()
    document.addEventListener('mousedown', this.handleClick, false);
  }

  componentWillUnmount() {
    document.removeEventListener('mousedown', this.handleClick, false);
  }

  handleClick(e) {
    if (this.dropDownNode && this.dropDownNode.contains(e.target)) return;
    if (!this.state.dropdownOpen) return;

    this.setState({dropdownOpen: false})
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
        <div className="w-full h-8 relative" style={{maxWidth: 'calc(100% - 14rem)'}}>
          <Bar count={value.count} all={this.state.breakdown} bg="bg-red-50" />
          <Link to={{search: query.toString()}} style={{marginTop: '-26px'}} className="hover:underline block px-2">
            { value.name }
          </Link>
        </div>
        <div>
          <span className="font-medium inline-block w-20 text-right">{numberFormatter(value.count)}</span>
          <span className="font-medium inline-block w-36 text-right">{numberFormatter(value.total_count)}</span>
        </div>
      </div>
    )
  }

  changeMetaKey(newKey) {
    this.setState({metaKey: newKey, loading: true, dropdownOpen: false}, this.fetchMetaBreakdown)
  }

  renderMetaKeyOption(key) {
    const extraClass = key === this.state.metaKey ? 'font-medium text-gray-900' : 'hover:bg-gray-100 hover:text-gray-900 focus:outline-none focus:bg-gray-100 focus:text-gray-900'

    return (
      <span onClick={this.changeMetaKey.bind(this, key)} key={key} className={`cursor-pointer block truncate px-4 py-2 text-sm leading-5 text-gray-700 ${extraClass}`}>
        {key}
      </span>
    )
  }

  renderDropdown() {
    return (
      <div className="py-1">
        { this.props.goal.meta_keys.map(this.renderMetaKeyOption.bind(this)) }
      </div>
    )
  }

  toggleDropdown() {
    this.setState({dropdownOpen: !this.state.dropdownOpen})
  }

  renderBody() {
    if (this.state.loading) {
      return <div className="px-4 py-2"><div className="loading sm mx-auto"><div></div></div></div>
    } else {
      return this.state.breakdown.map((metaValue) => this.renderMetadataValue(metaValue))
    }
  }

  render() {
    return (
      <div className="w-full pl-6 mt-4">
        <div className="relative">
          Breakdown by
          <button onClick={this.toggleDropdown.bind(this)} className="ml-1 inline-flex items-center rounded-md leading-5 font-bold text-gray-700 focus:outline-none transition ease-in-out duration-150 hover:text-gray-500 focus:border-blue-300 focus:shadow-outline-blue">
            { this.state.metaKey }
            <svg className="mt-px h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path fillRule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clipRule="evenodd" />
            </svg>
          </button>
          <Transition
            show={this.state.dropdownOpen}
            enter="transition ease-out duration-100 transform"
            enterFrom="opacity-0 scale-95"
            enterTo="opacity-100 scale-100"
            leave="transition ease-in duration-75 transform"
            leaveFrom="opacity-100 scale-100"
            leaveTo="opacity-0 scale-95"
          >
            <div className="z-10 origin-top-left absolute left-0 mt-2 w-64 rounded-md shadow-lg" ref={node => this.dropDownNode = node} >
              <div className="rounded-md bg-white shadow-xs">
                { this.renderDropdown() }
              </div>
            </div>
          </Transition>
        </div>
        { this.renderBody() }
      </div>
    )
  }
}
