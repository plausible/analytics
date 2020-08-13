import React from 'react';
import Transition from "../transition.js";

export default class SiteSwitcher extends React.Component {
  constructor() {
    super()
    this.handleClick = this.handleClick.bind(this)
    this.state = {
      open: false,
      sites: null,
      error: null,
      loading: true
    }
  }

  componentDidMount() {
    document.addEventListener('mousedown', this.handleClick, false);
  }

  componentWillUnmount() {
    document.removeEventListener('mousedown', this.handleClick, false);
  }

  handleClick(e) {
    if (this.dropDownNode && this.dropDownNode.contains(e.target)) return;
    if (!this.state.open) return;

    this.setState({open: false})
  }

  toggle() {
    if (!this.props.loggedIn) return;

    this.setState({open: !this.state.open})

    if (!this.state.sites) {
      fetch('/api/sites')
        .then( response => {
          if (!response.ok) { throw response }
          return response.json()
        })
        .then((sites) => this.setState({loading: false, sites: sites}))
        .catch((e) => this.setState({loading: false, error: e}))
    }
  }

  renderSiteLink(domain) {
    const extraClass = domain === this.props.site.domain ? 'font-medium text-gray-900' : 'hover:bg-gray-100 hover:text-gray-900 focus:outline-none focus:bg-gray-100 focus:text-gray-900'
    return (
      <a href={`/${encodeURIComponent(domain)}`} key={domain} className={`block truncate px-4 py-2 text-sm leading-5 text-gray-700 ${extraClass}`}>
        <img src={`https://icons.duckduckgo.com/ip3/${domain}.ico`} className="inline w-4 mr-2 align-middle" />
        <span>{domain}</span>
      </a>
    )
  }

  renderDropdown() {
    if (this.state.loading) {
      return <div className="px-4 py-6"><div className="loading sm mx-auto"><div></div></div></div>
    } else if (this.state.error) {
      return <div className="mx-auto px-4 py-6">Something went wrong, try again</div>
    } else {
      return (
        <React.Fragment>
          <div className="py-1">
            <a href={`/${encodeURIComponent(this.props.site.domain)}/settings`} className="group flex items-center px-4 py-2 text-sm leading-5 text-gray-700 hover:bg-gray-100 hover:text-gray-900 focus:outline-none focus:bg-gray-100 focus:text-gray-900" role="menuitem">
            <svg viewBox="0 0 20 20" fill="currentColor" className="mr-2 h-4 w-4 text-gray-500 group-hover:text-gray-600 group-focus:text-gray-500"><path d="M5 4a1 1 0 00-2 0v7.268a2 2 0 000 3.464V16a1 1 0 102 0v-1.268a2 2 0 000-3.464V4zM11 4a1 1 0 10-2 0v1.268a2 2 0 000 3.464V16a1 1 0 102 0V8.732a2 2 0 000-3.464V4zM16 3a1 1 0 011 1v7.268a2 2 0 010 3.464V16a1 1 0 11-2 0v-1.268a2 2 0 010-3.464V4a1 1 0 011-1z" /></svg>
              Site settings
            </a>
          </div>
          <div className="border-t border-gray-100"></div>
          <div className="py-1">
            { this.state.sites.map(this.renderSiteLink.bind(this)) }
          </div>
        </React.Fragment>
      )
    }
  }

  renderArrow() {
    if (this.props.loggedIn) {
      return (
        <svg className="-mr-1 ml-2 h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
          <path fillRule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clipRule="evenodd" />
        </svg>
      )
    }
  }

  render() {
    const hoverClass = this.props.loggedIn ? 'hover:text-gray-500 focus:border-blue-300 focus:shadow-outline-blue ' : 'cursor-default'

    return (
      <div className="relative inline-block text-left z-10 mr-8">
        <button onClick={this.toggle.bind(this)} className={`inline-flex items-center text-lg w-full rounded-md py-2 leading-5 font-bold text-gray-700 focus:outline-none transition ease-in-out duration-150 ${hoverClass}`}>

          <img src={`https://icons.duckduckgo.com/ip3/${this.props.site.domain}.ico`} className="inline w-4 mr-2 align-middle" />
          {this.props.site.domain}
          {this.renderArrow()}
        </button>

        <Transition
          show={this.state.open}
          enter="transition ease-out duration-100 transform"
          enterFrom="opacity-0 scale-95"
          enterTo="opacity-100 scale-100"
          leave="transition ease-in duration-75 transform"
          leaveFrom="opacity-100 scale-100"
          leaveTo="opacity-0 scale-95"
        >
        <div className="origin-top-left absolute left-0 mt-2 w-64 rounded-md shadow-lg" ref={node => this.dropDownNode = node} >
          <div className="rounded-md bg-white shadow-xs">
            { this.renderDropdown() }
          </div>
        </div>
        </Transition>
      </div>
    )
  }
}
