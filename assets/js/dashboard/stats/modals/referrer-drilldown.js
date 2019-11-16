import React from "react";
import { Link, withRouter } from 'react-router-dom'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter from '../../number-formatter'
import Bar from '../bar'
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
    api.get(`/api/stats/${this.props.site.domain}/referrers/${this.props.match.params.referrer}`, this.state.query, {limit: 100})
      .then((res) => this.setState({loading: false, referrers: res.referrers, totalVisitors: res.total_visitors}))
  }

  renderReferrer(referrer) {
    return (
      <React.Fragment key={referrer.name}>
        <div className="flex items-center justify-between my-2">
          <a className="hover:underline truncate" target="_blank" style={{maxWidth: '80%'}} href={'//' + referrer.name}>{ referrer.name }</a>
          <span>{numberFormatter(referrer.count)}</span>
        </div>
        <Bar count={referrer.count} all={this.state.referrers} color="blue" />
      </React.Fragment>
    )
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
            <h1>{this.state.totalVisitors} new visitors from {this.props.match.params.referrer}</h1>
            <h1 className="text-grey-darker" style={{transform: 'translateY(-1rem)'}}>{toHuman(this.state.query)}</h1>

            <div className="mt-4">
              { this.state.referrers.map(this.renderReferrer.bind(this)) }
            </div>
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
