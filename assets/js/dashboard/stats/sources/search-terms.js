import React from 'react';
import FadeIn from '../../fade-in'
import Bar from '../bar'
import MoreLink from '../more-link'
import { numberShortFormatter } from '../../util/number-formatter'
import RocketIcon from '../modals/rocket-icon'
import * as api from '../../api'
import LazyLoader from '../../components/lazy-loader'
import { referrersGoogleRoute } from '../../router';

export function ConfigureSearchTermsCTA({site}) {
  return (
    <>
      <div>Configure the integration to view search terms</div>
      <a href={`/${encodeURIComponent(site.domain)}/settings/integrations`} className="button mt-4">Connect with Google</a>
    </>
  )
}

export default class SearchTerms extends React.Component {
  constructor(props) {
    super(props)
    this.state = { loading: true, errorPayload: null }
    this.onVisible = this.onVisible.bind(this)
    this.fetchSearchTerms = this.fetchSearchTerms.bind(this)
  }

  onVisible() {
    this.fetchSearchTerms()
    if (this.props.query.period === 'realtime') {
      document.addEventListener('tick', this.fetchSearchTerms)
    }
  }

  componentDidUpdate(prevProps) {
    if (this.props.query !== prevProps.query) {
      this.setState({ loading: true, terms: null })
      this.fetchSearchTerms()
    }
  }

  componentWillUnmount() {
    document.removeEventListener('tick', this.fetchSearchTerms)
  }

  fetchSearchTerms() {
    api.get(this.props.site, `/api/stats/${encodeURIComponent(this.props.site.domain)}/referrers/Google`, this.props.query)
      .then((res) => this.setState({
        loading: false,
        searchTerms: res.results,
        errorPayload: null
      })).catch((error) => {
        this.setState({ loading: false, searchTerms: [], errorPayload: error.payload })
      })
  }

  renderSearchTerm(term) {
    return (
      <div className="flex items-center justify-between my-1 text-sm" key={term.name}>
        <Bar
          count={term.visitors}
          all={this.state.searchTerms}
          bg="bg-blue-50 dark:bg-gray-500 dark:bg-opacity-15"
          maxWidthDeduction="4rem"
        >
          <span className="flex px-2 py-1.5 dark:text-gray-300 z-9 relative break-all">
            <span className="md:truncate block">
              {term.name}
            </span>
          </span>
        </Bar>
        <span className="font-medium dark:text-gray-200">{numberShortFormatter(term.visitors)}</span>
      </div>
    )
  }

  renderList() {
    if (this.state.errorPayload) {
      const {reason, is_admin, error} = this.state.errorPayload

      return (
        <div className="text-center text-gray-700 dark:text-gray-300 text-sm mt-20">
          <RocketIcon />
          <div>{error}</div>
          {reason === 'not_configured' && is_admin && <ConfigureSearchTermsCTA site={this.props.site}/> }
        </div>
      )
    } else if (this.state.searchTerms.length > 0) {
      const valLabel = this.props.query.period === 'realtime' ? 'Current visitors' : 'Visitors'

      return (
        <React.Fragment>
          <div className="flex items-center mt-3 mb-2 justify-between text-gray-500 dark:text-gray-400 text-xs font-bold tracking-wide">
            <span>Search term</span>
            <span>{valLabel}</span>
          </div>

          {this.state.searchTerms.map(this.renderSearchTerm.bind(this))}
        </React.Fragment>
      )
    } else {
      return (
        <div className="text-center text-gray-700 dark:text-gray-300 ">
          <div className="mt-44 mx-auto font-medium text-gray-500 dark:text-gray-400">No data yet</div>
        </div>
      )
    }
  }

  renderContent() {
    if (this.state.searchTerms) {
      return (
        <React.Fragment>
          <h3 className="font-bold dark:text-gray-100">Search Terms</h3>
          {this.renderList()}
          <MoreLink list={this.state.searchTerms} linkProps={{ path: referrersGoogleRoute.path, search: (search) => search }} className="w-full pb-4 absolute bottom-0 left-0" />
        </React.Fragment>
      )
    }
  }

  render() {
    return (
      <div>
        {this.state.loading && <div className="loading mt-44 mx-auto"><div></div></div>}
        <FadeIn show={!this.state.loading} className="flex-grow">
          <LazyLoader onVisible={this.onVisible}>
            {this.renderContent()}
          </LazyLoader>
        </FadeIn>
      </div>
    )
  }
}
