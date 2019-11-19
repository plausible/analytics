import React from "react";
import { withRouter } from 'react-router-dom'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter from '../../number-formatter'
import Bar from '../bar'
import {parseQuery} from '../../query'

class PagesModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    const query = parseQuery(this.props.location.search, this.props.site)

    api.get(`/api/stats/${this.props.site.domain}/pages`, query, {limit: 100})
      .then((res) => this.setState({loading: false, pages: res}))
  }

  renderPage(page) {
    return (
      <React.Fragment key={page.name}>
        <div className="flex items-center justify-between my-2">
          <span>{ page.name }</span>
          <span>{numberFormatter(page.count)}</span>
        </div>
        <Bar count={page.count} all={this.state.pages} color="orange" />
      </React.Fragment>
    )
  }

  renderBody() {
    if (this.state.loading) {
      return (
        <div className="loading my-32 mx-auto"><div></div></div>
      )
    } else if (this.state.pages) {
      return (
        <React.Fragment>
          <header className="modal__header">
            <h1>Top pages</h1>
          </header>
          <div className="text-grey-darker text-lg ml-1 mt-1">by pageviews</div>

          <div className="my-4 border-b border-grey-light"></div>
          <main className="modal__content">
            <div className="mt-8">
              { this.state.pages.map(this.renderPage.bind(this)) }
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

export default withRouter(PagesModal)
