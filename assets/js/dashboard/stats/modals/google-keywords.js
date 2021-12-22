import React from "react";
import { Link, withRouter } from 'react-router-dom'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter from '../../util/number-formatter'
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
    if (this.state.query.filters.goal) {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/goal/referrers/Google`, this.state.query, {limit: 100})
        .then((res) => this.setState({
          loading: false,
          searchTerms: res.search_terms,
          totalVisitors: res.total_visitors,
          notConfigured: res.not_configured,
          isOwner: res.is_owner
        }))
    } else {
      api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/referrers/Google`, this.state.query, {limit: 100})
        .then((res) => this.setState({
          loading: false,
          searchTerms: res.search_terms,
          totalVisitors: res.total_visitors,
          notConfigured: res.not_configured,
          isOwner: res.is_owner
        }))
    }
  }

  renderTerm(term) {
    return (
      <React.Fragment key={term.name}>

        <tr className="text-sm dark:text-gray-200" key={term.name}>
          <td className="p-2 truncate">{term.name}</td>
          <td className="p-2 w-32 font-medium" align="right">{numberFormatter(term.visitors)}</td>
        </tr>
      </React.Fragment>
    )
  }

  renderKeywords() {
    if (this.state.query.filters.goal) {
      return (
        <div className="text-center text-gray-700 dark:text-gray-300 mt-6">
          <RocketIcon />
          <div className="text-lg">Sorry, we cannot show which keywords converted best for goal <b>{this.state.query.filters.goal}</b></div>
          <div className="text-lg">Google does not share this information</div>
        </div>
      )
    } else if (this.state.notConfigured) {
      if (this.state.isOwner) {
        return (
          <div className="text-center text-gray-700 dark:text-gray-300 mt-6">
            <RocketIcon />
            <div className="text-lg">The site is not connected to Google Search Keywords</div>
            <div className="text-lg">Configure the integration to view search terms</div>
            <a href={`/${encodeURIComponent(this.props.site.domain)}/settings/search-console`} className="button mt-4">Connect with Google</a>
          </div>
        )
      } else {
        return (
          <div className="text-center text-gray-700 dark:text-gray-300 mt-6">
            <RocketIcon />
            <div className="text-lg">The site is not connected to Google Search Kewyords</div>
            <div className="text-lg">Cannot show search terms</div>
          </div>
        )
      }
    } else if (this.state.searchTerms.length > 0) {
      return (
        <table className="w-max overflow-x-auto md:w-full table-striped table-fixed">
          <thead>
            <tr>
              <th className="p-2 w-48 md:w-56 lg:w-1/3 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="left">Search Term</th>
              <th className="p-2 w-32 lg:w-1/2 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">Visitors</th>
            </tr>
          </thead>
          <tbody>
            {this.state.searchTerms.map(this.renderTerm.bind(this))}
          </tbody>
        </table>
      )
    } else {
      return (
        <div className="text-center text-gray-700 dark:text-gray-300 mt-6">
          <RocketIcon />
          <div className="text-lg">Could not find any search terms for this period</div>
        </div>
      )
    }
  }

  renderGoalText() {
    if (this.state.query.filters.goal) {
      return (
        <h1 className="text-xl font-semibold text-gray-500 dark:text-gray-200 leading-none">completed {this.state.query.filters.goal}</h1>
      )
    }
  }

  renderBody() {
    if (this.state.loading) {
      return (
        <div className="loading mt-32 mx-auto"><div></div></div>
      )
    } else {
      return (
        <React.Fragment>
          <Link to={`/${encodeURIComponent(this.props.site.domain)}/referrers${window.location.search}`} className="font-bold text-gray-700 dark:text-gray-200 hover:underline">← All referrers</Link>

          <div className="my-4 border-b border-gray-300 dark:border-gray-500"></div>
          <main className="modal__content">
            <h1 className="text-xl font-semibold mb-0 leading-none dark:text-gray-200">
              {this.state.totalVisitors} visitors from Google<br />
              {toHuman(this.state.query)}
            </h1>
            {this.renderGoalText()}
            { this.renderKeywords() }
          </main>
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <Modal site={this.props.site} show={!this.state.loading}>
        { this.renderBody() }
      </Modal>
    )
  }
}

export default withRouter(GoogleKeywordsModal)
