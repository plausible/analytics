import React from "react";
import { Link, withRouter } from 'react-router-dom'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter from '../../number-formatter'
import Bar from '../bar'
import {parseQuery} from '../../query'

class ReferrersModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    const query = parseQuery(this.props.location.search, this.props.site)

    api.get(`/api/stats/${this.props.site.domain}/referrers`, query, {limit: 100})
      .then((res) => this.setState({loading: false, referrers: res}))
  }

  renderReferrer(referrer) {
    return (
      <React.Fragment key={referrer.name}>
        <div className="flex items-center justify-between my-2">
          <Link className="hover:underline truncate" style={{maxWidth: '80%'}} to={`/${this.props.site.domain}/referrers/${referrer.name}${window.location.search}`}>{ referrer.name }</Link>
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
            <h1>Referrers</h1>
          </header>
          <div className="text-grey-darker text-lg ml-1 mt-1">by new visitors</div>

          <div className="my-4 border-b border-grey-light"></div>
          <main className="modal__content">
            <div className="mt-8">
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

export default withRouter(ReferrersModal)
