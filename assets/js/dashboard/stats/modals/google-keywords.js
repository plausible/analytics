import React from "react";
import { Link, withRouter } from 'react-router-dom'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter from '../../number-formatter'
import Bar from '../bar'
import {parseQuery, toHuman} from '../../query'
import RocketIcon from './rocket-icon'

class GoogleKeywordsModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: true,
      query: parseQuery(props.location.search, props.site)
    }
  }

  componentDidMount() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/referrers/Google`, this.state.query, {limit: 100})
      .then((res) => this.setState({
        loading: false,
        searchTerms: res.search_terms,
        totalVisitors: res.total_visitors,
        notConfigured: res.not_configured,
        isOwner: res.is_owner
      }))
  }

  renderTerm(term) {
    return (
      <React.Fragment key={term.name}>

        <tr className="text-sm" key={term.name}>
          <td className="p-2 truncate">{term.name}</td>
          <td className="p-2 w-32 font-medium" align="right">{numberFormatter(term.count)}</td>
        </tr>
      </React.Fragment>
    )
  }

  renderKeywords() {
    if (this.state.query.filters.goal) {
      return (
        <div className="text-center text-grey-darker mt-6">
          <RocketIcon />
          <div className="text-lg">Sorry, we cannot show which keywords converted best for goal <b>{this.state.query.filters.goal}</b></div>
          <div className="text-lg">Google does not share this information</div>
        </div>
      )
    } else if (this.state.notConfigured) {
      if (this.state.isOwner) {
        return (
          <div className="text-center text-grey-darker mt-6">
            <RocketIcon />
            <div className="text-lg">The site is not connected to Google Search Keywords</div>
            <div className="text-lg">Configure the integration to view search terms</div>
            <a href={`/${encodeURIComponent(this.props.site.domain)}/settings#google-auth`} className="button mt-4">Connect with Google</a>
          </div>
        )
      } else {
        return (
          <div className="text-center text-grey-darker mt-6">
            <RocketIcon />
            <div className="text-lg">The site is not connected to Google Search Kewyords</div>
            <div className="text-lg">Cannot show search terms</div>
          </div>
        )
      }
    } else if (this.state.searchTerms.length > 0) {
      return (
        this.state.searchTerms.map(this.renderTerm.bind(this))
      )
    } else {
      return (
        <div className="text-center text-grey-darker mt-6">
          <RocketIcon />
          <div className="text-lg">Could not find any search terms for this period</div>
        </div>
      )
    }
  }

  renderBody() {
    if (this.state.loading) {
      return (
        <div className="loading my-32 mx-auto"><div></div></div>
      )
    } else {
      return (
        <React.Fragment>
          <header className="modal__header">
            <Link to={`/${encodeURIComponent(this.props.site.domain)}/referrers${window.location.search}`} className="font-bold text-grey-darker hover:underline">← All referrers</Link>
          </header>

          <div className="my-4 border-b border-grey-light"></div>
          <main className="modal__content mt-0">
            <h1>{this.state.totalVisitors} new visitors from Google</h1>
            <h1 className="text-grey-darker" style={{transform: 'translateY(-1rem)'}}>{toHuman(this.state.query)}</h1>

            <table className="w-full table-striped table-fixed">
              <thead>
                <tr>
                  <th className="p-2 text-xs tracking-wide font-bold text-grey-dark" align="left">Search Term</th>
                  <th className="p-2 w-32 text-xs tracking-wide font-bold text-grey-dark" align="right">Visitors</th>
                </tr>
              </thead>
              <tbody>
                { this.renderKeywords() }
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

export default withRouter(GoogleKeywordsModal)
