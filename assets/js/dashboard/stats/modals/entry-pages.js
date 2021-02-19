import React from "react";
import { Link } from 'react-router-dom'
import { withRouter } from 'react-router-dom'

import Modal from './modal'
import * as api from '../../api'
import numberFormatter, { durationFormatter } from '../../number-formatter'
import {parseQuery} from '../../query'

class EntryPagesModal extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      loading: true,
      query: parseQuery(props.location.search, props.site),
      pages: [],
      page: 1,
      moreResultsAvailable: false
    }
  }

  componentDidMount() {
    this.loadPages();
  }

  loadPages() {
    const {query, page, pages} = this.state;

    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/entry-pages`, query, {limit: 100, page})
      .then((res) => this.setState((state) => ({loading: false, pages: state.pages.concat(res), moreResultsAvailable: res.length === 100})))
  }

  loadMore() {
    this.setState({loading: true, page: this.state.page + 1}, this.loadPages.bind(this))
  }

  showVisitDuration() {
    return this.state.query.period !== 'realtime'
  }

  formatBounceRate(page) {
    if (typeof(page.bounce_rate) === 'number') {
      return page.bounce_rate + '%'
    } else {
      return '-'
    }
  }

  renderPage(page) {
    const query = new URLSearchParams(window.location.search)
    query.set('entry_page', page.name)

    return (
      <tr className="text-sm dark:text-gray-200" key={page.name}>
        <td className="p-2">
          <Link to={{pathname: `/${encodeURIComponent(this.props.site.domain)}`, search: query.toString()}} className="hover:underline">{page.name}</Link>
        </td>
        <td className="p-2 w-32 font-medium" align="right">{numberFormatter(page.count)}</td>
        <td className="p-2 w-32 font-medium" align="right">{numberFormatter(page.entries)}</td>
        {this.showVisitDuration() && <td className="p-2 w-32 font-medium" align="right">{durationFormatter(page.visit_duration)}</td>}
      </tr>
    )
  }

  renderLoading() {
    if (this.state.loading) {
      return <div className="loading my-16 mx-auto"><div></div></div>
    } else if (this.state.moreResultsAvailable) {
      return (
        <div className="w-full text-center my-4">
          <button onClick={this.loadMore.bind(this)} type="button" className="button">
            Load more
          </button>
        </div>
      )
    }
  }

  renderBody() {
    if (this.state.pages) {
      return (
        <React.Fragment>
          <h1 className="text-xl font-bold dark:text-gray-100">Entry Pages</h1>

          <div className="my-4 border-b border-gray-300"></div>
          <main className="modal__content">
            <table className="w-full table-striped table-fixed">
              <thead>
                <tr>
                  <th className="p-2 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="left">Page url</th>
                  <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">Unique Entrances</th>
                  <th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">Total Entrances</th>
                  {<th className="p-2 w-32 text-xs tracking-wide font-bold text-gray-500 dark:text-gray-400" align="right">Visit Duration</th>}
                </tr>
              </thead>
              <tbody>
                { this.state.pages.map(this.renderPage.bind(this)) }
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
        { this.renderLoading() }
      </Modal>
    )
  }
}

export default withRouter(EntryPagesModal)
