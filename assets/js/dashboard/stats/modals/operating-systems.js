import React from "react";
import { withRouter } from 'react-router-dom'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter from '../../number-formatter'
import Bar from '../bar'
import {parseQuery} from '../../query'

class OperatingSystemsModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    const query = parseQuery(this.props.location.search, this.props.site)

    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/operating-systems`, query, {limit: 100})
      .then((res) => this.setState({loading: false, systems: res}))
  }

  renderSystem(system) {
    return (
      <React.Fragment key={system.name}>
        <div className="flex items-center justify-between my-2">
          <span>{system.name}</span>
          <span>{system.percentage}%</span>
        </div>
        <Bar count={system.count} all={this.state.systems} color="blue" />
      </React.Fragment>
    )
  }

  renderBody() {
    if (this.state.loading) {
      return (
        <div className="loading my-32 mx-auto"><div></div></div>
      )
    } else if (this.state.systems) {
      return (
        <React.Fragment>
          <header className="modal__header">
            <h1>Operating Systems</h1>
          </header>
          <div className="text-grey-darker text-lg ml-1 mt-1">by visitors</div>

          <div className="my-4 border-b border-grey-light"></div>
          <main className="modal__content">
            <div className="mt-8">
              { this.state.systems.map(this.renderSystem.bind(this)) }
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

export default withRouter(OperatingSystemsModal)
