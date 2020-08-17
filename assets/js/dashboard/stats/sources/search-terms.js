import React from 'react';
import FadeIn from '../../fade-in'
import Bar from '../bar'
import MoreLink from '../more-link'
import numberFormatter from '../../number-formatter'
import * as api from '../../api'

export default class SearchTerms extends React.Component {
  constructor(props) {
    super(props)
    this.state = {loading: true}
  }

  componentDidMount() {
    this.fetchSearchTerms()
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({loading: true, terms: null})
      this.fetchSearchTerms()
    }
  }

  fetchSearchTerms() {
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/referrers/${encodeURIComponent(this.props.query.filters.source)}`, this.props.query)
      .then((res) => res.search_terms)
      .then((terms) => this.setState({loading: false, terms: terms}))
  }

  renderSearchTerm(term) {
    return (
      <div className="flex items-center justify-between my-1 text-sm" key={term.name}>
        <div className="w-full h-8" style={{maxWidth: 'calc(100% - 4rem)'}}>
          <Bar count={term.count} all={this.state.terms} bg="bg-blue-50" />
          <span className="flex px-2" style={{marginTop: '-26px'}} >
            <span className="block truncate">
              <img src={`https://icons.duckduckgo.com/ip3/${term.url}.ico`} className="inline h-4 w-4 mr-2 align-middle -mt-px" />
              { term.name }
            </span>
          </span>
        </div>
        <span className="font-medium">{numberFormatter(term.count)}</span>
      </div>
    )
  }

  renderList() {
    if (this.state.terms.length > 0) {
      const valLabel = this.props.query.period === 'realtime' ? 'Active visitors' : 'Visitors'

      return (
        <React.Fragment>
          <div className="flex items-center mt-3 mb-2 justify-between text-gray-500 text-xs font-bold tracking-wide">
            <span>Search term</span>
            <span>{valLabel}</span>
          </div>

          {this.state.terms.map(this.renderSearchTerm.bind(this))}
        </React.Fragment>
      )
    } else {
      return <div className="text-center mt-44 font-medium text-gray-500">No data yet</div>
    }
  }

  renderContent() {
    if (this.state.terms) {
      return (
        <React.Fragment>
          <h3 className="font-bold">Search Terms</h3>
          { this.renderList() }
          <MoreLink site={this.props.site} list={this.state.terms} endpoint="referrers/Google" />
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <div className="stats-item relative bg-white shadow-xl rounded p-4" style={{height: '436px'}}>
        { this.state.loading && <div className="loading mt-44 mx-auto"><div></div></div> }
        <FadeIn show={!this.state.loading}>
          { this.renderContent() }
        </FadeIn>
      </div>
    )
  }
}
