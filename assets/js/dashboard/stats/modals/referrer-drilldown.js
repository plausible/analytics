import React from "react";
import { Link, withRouter } from 'react-router-dom'
import TweetEmbed from 'react-tweet-embed'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter from '../../number-formatter'
import {parseQuery, toHuman} from '../../query'

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
      api.get(`/api/stats/${this.props.site.domain}/goal/referrers/${this.props.match.params.referrer}`, this.state.query, {limit: 100})
        .then((res) => this.setState({loading: false, referrers: res.referrers, totalVisitors: res.total_visitors}))
    } else {
      const include = this.showBounceRate() ? 'bounce_rate' : null

      api.get(`/api/stats/${this.props.site.domain}/referrers/${this.props.match.params.referrer}`, this.state.query, {limit: 100, include: include})
        .then((res) => this.setState({loading: false, referrers: res.referrers, totalVisitors: res.total_visitors}))
    }
  }

  showBounceRate() {
    return !this.state.query.filters.goal
  }

  formatBounceRate(ref) {
    if (ref.bounce_rate) {
      return ref.bounce_rate + '%'
    } else {
      return '-'
    }
  }

  renderReferrerName(name) {
    if (name) {
      return <a className="hover:underline" target="_blank" href={'//' + name}>{name}</a>
    } else {
      return '(no referrer)'
    }
  }

  renderTweet(tweet, index) {
    const authorUrl = `https://twitter.com/${tweet.author_handle}`
    const tweetUrl = `${authorUrl}/status/${tweet.tweet_id}`
    const border = index === 0 ? '' : ' pt-4 border-t border-grey-light'

    return (
      <div key={tweet.tweet_id}>
        <div className={"flex items-center my-4" + border} >
          <a className="flex items-center group" href={authorUrl} target="_blank">
            <img className="rounded-full w-6" src={tweet.author_image} />
            <div className="font-bold ml-2 group-hover:text-blue">{tweet.author_name}</div>
            <div className="ml-2 text-xs text-grey-dark">@{tweet.author_handle}</div>
          </a>
          <a className="ml-auto twitter-icon" href={tweetUrl} target="_blank"></a>
        </div>
        <div className="my-2 cursor-text tweet-text" dangerouslySetInnerHTML={{__html: tweet.text}}>
        </div>
        <div className="text-xs text-grey-darker font-medium">
          {tweet.created}
        </div>
      </div>
    )
  }

  renderReferrer(referrer) {
    if (false && referrer.tweets) {
      return (
        <tr className="text-sm" key={referrer.name}>
          <td className="p-2">
            { this.renderReferrerName(referrer.name) }
            <span className="text-grey-dark ml-2 text-xs">
              appears in {referrer.tweets.length} tweets
              <svg className="feather ml-1"><use xlinkHref="#feather-chevron-down" /></svg>
            </span>
            <div className="my-4 ml-4">
              { referrer.tweets.map(this.renderTweet) }
            </div>
          </td>
          <td className="p-2 w-32 font-medium" align="right" valign="top">{numberFormatter(referrer.count)}</td>
          {this.showBounceRate() && <td className="p-2 w-32 font-medium" align="right" valign="top">{this.formatBounceRate(referrer)}</td> }
        </tr>
      )
    } else {
      return (
        <tr className="text-sm" key={referrer.name}>
          <td className="p-2 truncate">
            { this.renderReferrerName(referrer.name) }
          </td>
          <td className="p-2 w-32 font-medium" align="right">{numberFormatter(referrer.count)}</td>
          {this.showBounceRate() && <td className="p-2 w-32 font-medium" align="right">{this.formatBounceRate(referrer)}</td> }
        </tr>
      )
    }
  }

  renderGoalText() {
    if (this.state.query.filters.goal) {
      return (
        <h1 className="text-grey-darker leading-none">completed {this.state.query.filters.goal}</h1>
      )
    }
  }

  renderBody() {
    if (this.state.loading) {
      return (
        <div className="loading my-32 mx-auto"><div></div></div>
      )
    } else if (this.state.referrers) {
      return (
        <React.Fragment>
          <header className="modal__header">
            <Link to={`/${this.props.site.domain}/referrers${window.location.search}`} className="font-bold text-grey-darker hover:underline">← All referrers</Link>
          </header>

          <div className="my-4 border-b border-grey-light"></div>
          <main className="modal__content mt-0">
            <h1 className="mb-0 leading-none">{this.state.totalVisitors} visitors from {this.props.match.params.referrer}<br /> {toHuman(this.state.query)}</h1>
            {this.renderGoalText()}

            <table className="w-full table-striped table-fixed mt-4">
              <thead>
                <tr>
                  <th className="p-2 text-xs tracking-wide font-bold text-grey-dark" align="left">Referrer</th>
                  <th className="p-2 w-32 text-xs tracking-wide font-bold text-grey-dark" align="right">Visitors</th>
                  {this.showBounceRate() && <th className="p-2 w-32 text-xs tracking-wide font-bold text-grey-dark" align="right">Bounce rate</th>}
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
