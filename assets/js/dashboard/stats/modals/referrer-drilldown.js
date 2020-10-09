import React from "react";
import { Link, withRouter } from 'react-router-dom'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter, {durationFormatter} from '../../number-formatter'
import {parseQuery, toHuman} from '../../query'
import {formatFullDate} from '../../date'

class ReferrerDrilldownModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: true,
      query: parseQuery(props.location.search, props.site)
    }
  }

  componentDidMount() {
    if (this.state.query.filters.goal) {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/goal/referrers/${this.props.match.params.referrer}`, this.state.query, {limit: 100})
        .then((res) => this.setState({loading: false, referrers: res.referrers, totalVisitors: res.total_visitors}))
    } else {
      const include = this.showExtra() ? 'bounce_rate,visit_duration' : null

      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/referrers/${this.props.match.params.referrer}`, this.state.query, {limit: 100, include: include})
        .then((res) => this.setState({loading: false, referrers: res.referrers, totalVisitors: res.total_visitors}))
    }
  }

  showExtra() {
    return this.state.query.period !== 'realtime' && !this.state.query.filters.goal
  }

  formatBounceRate(ref) {
    if (typeof(ref.bounce_rate) === 'number') {
      return ref.bounce_rate + '%'
    } else {
      return '-'
    }
  }

  formatDuration(referrer) {
    if (typeof(referrer.visit_duration) === 'number') {
      return durationFormatter(referrer.visit_duration)
    } else {
      return '-'
    }
  }

  renderExternalLink(name) {
    if (name !== 'Direct / None') {
      return (
        <a target="_blank" href={'//' + name} className="hidden group-hover:block">
          <svg className="inline h-4 w-4 ml-1 -mt-1 text-gray-600" fill="currentColor" viewBox="0 0 20 20"><path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z"></path><path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z"></path></svg>
        </a>
      )
    }
  }

  renderReferrerName(name) {
    const query = new URLSearchParams(window.location.search)
    query.set('referrer', name)

    return (
      <span className="flex group">
        <Link className="block truncate hover:underline" to={{search: query.toString(), pathname: '/' + this.props.site.domain}} title={name}>
          {name}
        </Link>
        { this.renderExternalLink(name) }
      </span>
    )
  }

  renderTweet(tweet, index) {
    const authorUrl = `https://twitter.com/${tweet.author_handle}`
    const tweetUrl = `${authorUrl}/status/${tweet.tweet_id}`
    const border = index === 0 ? '' : ' pt-4 border-t border-gray-300'

    return (
      <div key={tweet.tweet_id}>
        <div className={"flex items-center my-4" + border} >
          <a className="flex items-center group" href={authorUrl} target="_blank">
            <img className="rounded-full w-8" src={tweet.author_image} />
            <div className="ml-2 leading-tight">
              <div className="font-bold group-hover:text-blue-500">{tweet.author_name}</div>
              <div className="text-xs text-gray-500">@{tweet.author_handle}</div>
            </div>
          </a>
          <a className="ml-auto twitter-icon" href={tweetUrl} target="_blank"></a>
        </div>
        <div className="my-2 cursor-text tweet-text whitespace-pre-wrap" dangerouslySetInnerHTML={{__html: tweet.text}}>
        </div>
        <div className="text-xs text-gray-700 font-medium">
          {formatFullDate(new Date(tweet.created))}
        </div>
      </div>
    )
  }

  renderReferrer(referrer) {
    if (referrer.tweets) {
      return (
        <tr className="text-sm" key={referrer.name}>
          <td className="p-2">
            { this.renderReferrerName(referrer.name) }
            <span className="text-gray-500 ml-2 text-xs">
              appears in {referrer.tweets.length} tweets
            </span>
            <div className="my-4 pl-4 border-l-2 border-gray-300">
              { referrer.tweets.map(this.renderTweet) }
            </div>
          </td>
          <td className="p-2 w-32 font-medium" align="right" valign="top">{numberFormatter(referrer.count)}</td>
          {this.showExtra() && <td className="p-2 w-32 font-medium" align="right" valign="top">{this.formatBounceRate(referrer)}</td> }
          {this.showExtra() && <td className="p-2 w-32 font-medium" align="right" valign="top">{this.formatDuration(referrer)}</td> }
        </tr>
      )
    } else {
      return (
        <tr className="text-sm" key={referrer.name}>
          <td className="p-2 truncate">
            { this.renderReferrerName(referrer.name) }
          </td>
          <td className="p-2 w-32 font-medium" align="right">{numberFormatter(referrer.count)}</td>
          {this.showExtra() && <td className="p-2 w-32 font-medium" align="right">{this.formatBounceRate(referrer)}</td> }
          {this.showExtra() && <td className="p-2 w-32 font-medium" align="right">{this.formatDuration(referrer)}</td> }
        </tr>
      )
    }
  }

  renderGoalText() {
    if (this.state.query.filters.goal) {
      return (
        <h1 className="text-xl font-semibold text-gray-500 leading-none">completed {this.state.query.filters.goal}</h1>
      )
    }
  }

  renderBody() {
    if (this.state.loading) {
      return (
        <div className="loading mt-32 mx-auto"><div></div></div>
      )
    } else if (this.state.referrers) {
      return (
        <React.Fragment>
          <h1 className="text-xl font-bold">Referrer drilldown</h1>

          <div className="my-4 border-b border-gray-300"></div>
          <main className="modal__content mt-0">
            <h1 className="text-xl font-semibold mb-0 leading-none">{this.state.totalVisitors} visitors from {decodeURIComponent(this.props.match.params.referrer)}<br /> {toHuman(this.state.query)}</h1>
            {this.renderGoalText()}

            <table className="w-full table-striped table-fixed mt-4">
              <thead>
                <tr>
                  <th className="p-2 text-xs tracking-wide font-bold text-gray-500" align="left">Referrer</th>
                  <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500" align="right">Visitors</th>
                  {this.showExtra() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500" align="right">Bounce rate</th>}
                  {this.showExtra() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500" align="right">Visit duration</th>}
                </tr>
              </thead>
              <tbody>
                { this.state.referrers.map(this.renderReferrer.bind(this)) }
              </tbody>
            </table>
          </main>
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <Modal site={this.props.site}>
        { this.renderBody() }
      </Modal>
    )
  }
}

export default withRouter(ReferrerDrilldownModal)
