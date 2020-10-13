import React from 'react';
import FadeIn from '../../fade-in'
import Bar from '../bar'
import MoreLink from '../more-link'
import numberFormatter from '../../number-formatter'
import RocketIcon from '../modals/rocket-icon'
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
    api.get(`/api/stats/${encodeURIComponent(this.props.site.domain)}/referrers/Google`, this.props.query)
      .then((res) => this.setState({
        loading: false,
        searchTerms: res.search_terms || [],
        notConfigured: res.not_configured,
        isOwner: res.is_owner
      }))
  }

  renderSearchTerm(term) {
    return (
      <div className="flex items-center justify-between my-1 text-sm" key={term.name}>
        <div className="w-full h-8" style={{maxWidth: 'calc(100% - 4rem)'}}>
          <Bar count={term.count} all={this.state.searchTerms} bg="bg-blue-50" />
          <span className="flex px-2" style={{marginTop: '-26px'}} >
            <span className="block truncate">
              { term.name }
            </span>
          </span>
        </div>
        <span className="font-medium">{numberFormatter(term.count)}</span>
      </div>
    )
  }

  renderList() {
    if (this.props.query.filters.goal) {
      return (
        <div className="text-center text-gray-700 text-sm mt-20">
          <RocketIcon />
          <div>Sorry, we cannot show which keywords converted best for goal <b>{this.props.query.filters.goal}</b></div>
          <div>Google does not share this information</div>
        </div>
      )

    } else if (this.state.notConfigured) {
      return (
        <div className="text-center text-gray-700 text-sm mt-20">
          <RocketIcon />
          <div>The site is not connected to Google Search Keywords</div>
          <div>Cannot show search terms</div>
          {this.state.isOwner && <a href={`/${encodeURIComponent(this.props.site.domain)}/settings#google-auth`} className="button mt-4">Connect with Google</a> }
        </div>
      )
    } else if (this.state.searchTerms.length > 0) {
      const valLabel = this.props.query.period === 'realtime' ? 'Current visitors' : 'Visitors'

      return (
        <React.Fragment>
          <div className="flex items-center mt-3 mb-2 justify-between text-gray-500 text-xs font-bold tracking-wide">
            <span>Search term</span>
            <span>{valLabel}</span>
          </div>

          {this.state.searchTerms.map(this.renderSearchTerm.bind(this))}
        </React.Fragment>
      )
    } else {
      return (
        <div className="text-center text-gray-700 text-sm mt-20">
          <RocketIcon />
          <div>Could not find any search terms for this period</div>
          <div>Google Search Console data is sampled and delayed by 24-36h</div>
          <div>Read more on <a href="https://docs.plausible.io/google-search-console-integration/#i-dont-see-google-search-query-data-in-my-dashboard" target="_blank" className="hover:underline text-indigo-700">our documentation</a></div>
        </div>
      )
    }
  }

  renderContent() {
    if (this.state.searchTerms) {
      return (
        <React.Fragment>
          <h3 className="font-bold">Search Terms</h3>
          { this.renderList() }
          <MoreLink site={this.props.site} list={this.state.searchTerms} endpoint="referrers/Google" />
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
