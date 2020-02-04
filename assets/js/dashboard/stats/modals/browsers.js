import React from "react";
import { withRouter } from 'react-router-dom'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter from '../../number-formatter'
import Bar from '../bar'
import {parseQuery} from '../../query'

class BrowsersModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    const query = parseQuery(this.props.location.search, this.props.site)

    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/browsers`, query, {limit: 100})
      .then((res) => this.setState({loading: false, browsers: res}))
  }

  renderBrowser(browser) {
    return (
      <React.Fragment key={browser.name}>
        <div className="flex items-center justify-between my-2">
          <span>{browser.name}</span>
          <span>{browser.percentage}%</span>
        </div>
        <Bar count={browser.count} all={this.state.browsers} color="red" />
      </React.Fragment>
    )
  }

  renderBody() {
    if (this.state.loading) {
      return (
        <div className="loading my-32 mx-auto"><div></div></div>
      )
    } else if (this.state.browsers) {
      return (
        <React.Fragment>
          <header className="modal__header">
            <h1>Top browsers</h1>
          </header>
          <div className="text-grey-darker text-lg ml-1 mt-1">by visitors</div>

          <div className="my-4 border-b border-grey-light"></div>
          <main className="modal__content">
            <div className="mt-8">
              { this.state.browsers.map(this.renderBrowser.bind(this)) }
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

export default withRouter(BrowsersModal)
