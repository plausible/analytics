import React from 'react';
import { Link } from 'react-router-dom'
import FlipMove from 'react-flip-move';

import FadeIn from '../../fade-in'
import Bar from '../bar'
import MoreLink from '../more-link'
import numberFormatter from '../../number-formatter'
import * as api from '../../api'

export default class Referrers extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    this.fetchReferrers()
    if (this.props.timer) this.props.timer.onTick(this.fetchReferrers.bind(this))
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, referrers: null})
      this.fetchReferrers()
    }
  }

  showNoRef() {
    return this.props.query.period === 'realtime'
  }

  fetchReferrers() {
    if (this.props.query.filters.goal) {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/goal/referrers`, this.props.query)
        .then((res) => this.setState({loading: false, referrers: res}))
    } else {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/referrers`, this.props.query, {show_noref: this.showNoRef()})
        .then((res) => this.setState({loading: false, referrers: res}))
    }
  }

  renderReferrer(referrer) {
    const query = new URLSearchParams(window.location.search)
    query.set('source', referrer.name)

    return (
      <div className="flex items-center justify-between my-1 text-sm" key={referrer.name}>
        <div className="w-full h-8" style={{maxWidth: 'calc(100% - 4rem)'}}>
          <Bar count={referrer.count} all={this.state.referrers} bg="bg-blue-50" />
          <span className="flex px-2" style={{marginTop: '-26px'}} >
            <Link className="block truncate hover:underline" to={{search: query.toString()}}>
              <img src={`https://icons.duckduckgo.com/ip3/${referrer.url}.ico`} className="inline h-4 w-4 mr-2 align-middle -mt-px" />
              { referrer.name }
            </Link>
          </span>
        </div>
        <span className="font-medium">{numberFormatter(referrer.count)}</span>
      </div>
    )
  }

  label() {
    return this.props.query.period === 'realtime' ? 'Active visitors' : 'Visitors'
  }

  renderList() {
    if (this.state.referrers.length > 0) {
      return (
        <React.Fragment>
          <div className="flex items-center mt-3 mb-2 justify-between text-gray-500 text-xs font-bold tracking-wide">
            <span>Source</span>
            <span>{this.label()}</span>
          </div>

          <FlipMove>
            {this.state.referrers.map(this.renderReferrer.bind(this))}
          </FlipMove>
        </React.Fragment>
      )
    } else {
      return <div className="text-center mt-44 font-medium text-gray-500">No data yet</div>
    }
  }

  renderContent() {
    if (this.state.referrers) {
      return (
        <React.Fragment>
          <h3 className="font-bold">Top sources</h3>
          { this.renderList() }
          <MoreLink site={this.props.site} list={this.state.referrers} endpoint="referrers" />
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <div className="stats-item relative bg-white shadow-xl rounded p-4" style={{height: '436px'}}>
        { this.state.loading && <div className="loading mt-44 mx-auto"><div></div></div> }
        <FadeIn show={!this.state.loading}>
          { this.renderContent() }
        </FadeIn>
      </div>
    )
  }
}
