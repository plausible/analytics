/**
 * @prettier
 */
import React from 'react'
import { Transition } from '@headlessui/react'
import { Cog8ToothIcon, ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'

function Favicon({ domain, className }) {
  return (
    <img
      alt=""
      src={`/favicon/sources/${encodeURIComponent(domain)}`}
      onError={(e) => {
        e.target.onerror = null
        e.target.src = '/favicon/sources/placeholder'
      }}
      referrerPolicy="no-referrer"
      className={className}
    />
  )
}

export default class SiteSwitcher extends React.Component {
  constructor() {
    super()
    this.handleClick = this.handleClick.bind(this)
    this.handleKeydown = this.handleKeydown.bind(this)
    this.populateSites = this.populateSites.bind(this)
    this.toggle = this.toggle.bind(this)
    this.siteSwitcherButton = React.createRef()
    this.state = {
      open: false,
      sites: null,
      error: null,
      loading: true
    }
  }

  componentDidMount() {
    this.populateSites()
    this.siteSwitcherButton.current.addEventListener('click', this.toggle)
    document.addEventListener('keydown', this.handleKeydown)
    document.addEventListener('click', this.handleClick, false)
  }

  componentWillUnmount() {
    this.siteSwitcherButton.current.removeEventListener('click', this.toggle)
    document.removeEventListener('keydown', this.handleKeydown)
    document.removeEventListener('click', this.handleClick, false)
  }

  populateSites() {
    if (!this.props.loggedIn) return

    fetch('/api/sites')
      .then((response) => {
        if (!response.ok) {
          throw response
        }
        return response.json()
      })
      .then((sites) =>
        this.setState({
          loading: false,
          sites: sites.data.map((s) => s.domain)
        })
      )
      .catch((e) => this.setState({ loading: false, error: e }))
  }

  handleClick(e) {
    // If this is an interaction with the dropdown menu itself, do nothing.
    if (this.dropDownNode && this.dropDownNode.contains(e.target)) return

    // If the dropdown is not open, do nothing.
    if (!this.state.open) return

    // In any other case, close it.
    this.setState({ open: false })
  }

  handleKeydown(e) {
    if (!this.props.loggedIn) return

    const { site } = this.props
    const { sites } = this.state

    if (e.target.tagName === 'INPUT') return true
    if (
      e.ctrlKey ||
      e.metaKey ||
      e.altKey ||
      e.isComposing ||
      e.keyCode === 229 ||
      !sites
    )
      return

    const siteNum = parseInt(e.key)

    if (
      1 <= siteNum &&
      siteNum <= 9 &&
      siteNum <= sites.length &&
      sites[siteNum - 1] !== site.domain
    ) {
      // has to change window.location because Router is rendered with /${site.domain} as the basepath
      window.location = `/${encodeURIComponent(sites[siteNum - 1])}`
    }
  }

  toggle(e) {
    /**
     * React doesn't seem to prioritise its own events when events are bubbling, and is unable to stop its events from propagating to the document's (root) event listeners which are attached on the DOM.
     *
     * A simple trick is to hook up our own click event listener via a ref node, which allows React to manage events in this situation better between the two.
     */
    e.stopPropagation()
    e.preventDefault()
    if (!this.props.loggedIn) return

    this.setState((prevState) => ({
      open: !prevState.open
    }))

    if (this.props.loggedIn && !this.state.sites) {
      this.populateSites()
    }
  }

  renderSiteLink(domain, index) {
    const extraClass =
      domain === this.props.site.domain
        ? 'font-medium text-gray-900 dark:text-gray-100 cursor-default font-bold'
        : 'hover:bg-gray-100 dark:hover:bg-gray-900 hover:text-gray-900 dark:hover:text-gray-100 focus:outline-none focus:bg-gray-100 dark:focus:bg-gray-900 focus:text-gray-900 dark:focus:text-gray-100'
    const showHotkey = this.props.loggedIn && this.state.sites.length > 1
    return (
      <a
        href={
          domain === this.props.site.domain
            ? null
            : `/${encodeURIComponent(domain)}`
        }
        key={domain}
        className={`flex items-center justify-between truncate px-4 py-2 md:text-sm leading-5 text-gray-700 dark:text-gray-300 ${extraClass}`}
      >
        <span>
          <Favicon
            domain={domain}
            className="inline w-4 mr-2 align-middle"
          ></Favicon>
          <span className="truncate inline-block align-middle max-w-3xs pr-2">
            {domain}
          </span>
        </span>
        {showHotkey && index < 9 ? <span>{index + 1}</span> : null}
      </a>
    )
  }

  renderSettingsLink() {
    if (
      ['owner', 'admin', 'editor', 'super_admin'].includes(
        this.props.currentUserRole
      )
    ) {
      return (
        <React.Fragment>
          <div className="py-1">
            <a
              href={`/${encodeURIComponent(
                this.props.site.domain
              )}/settings/general`}
              className="group flex items-center px-4 py-2 md:text-sm leading-5 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-900 hover:text-gray-900 dark:hover:text-gray-100 focus:outline-none focus:bg-gray-100 dark:focus:bg-gray-900 focus:text-gray-900 dark:focus:text-gray-100"
              role="menuitem"
            >
              <Cog8ToothIcon className="mr-2 h-4 w-4 text-gray-500 dark:text-gray-200 group-hover:text-gray-600 dark:group-hover:text-gray-400 group-focus:text-gray-500 dark:group-focus:text-gray-200" />
              Site Settings
            </a>
          </div>
          <div className="border-t border-gray-200 dark:border-gray-500"></div>
        </React.Fragment>
      )
    }
  }

  /**
   * Render a dropdown regardless of whether the user is logged in or not. In case they are not logged in (such as in an embed), the dropdown merely contains the current domain name.
   */
  renderDropdown() {
    if (this.state.loading) {
      return (
        <div className="px-4 py-6">
          <div className="loading sm mx-auto">
            <div></div>
          </div>
        </div>
      )
    } else if (this.state.error) {
      return (
        <div className="mx-auto px-4 py-6 dark:text-gray-100">
          Something went wrong, try again
        </div>
      )
    } else if (!this.props.loggedIn) {
      return (
        <React.Fragment>
          <div className="py-1">
            {[this.props.site.domain].map(this.renderSiteLink.bind(this))}
          </div>
        </React.Fragment>
      )
    } else {
      return (
        <React.Fragment>
          {this.renderSettingsLink()}
          <div className="py-1">
            {this.state.sites.map(this.renderSiteLink.bind(this))}
          </div>
          <div className="border-t border-gray-200 dark:border-gray-500"></div>
          <a
            href="/sites"
            className="flex px-4 py-2 md:text-sm leading-5 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-900 hover:text-gray-900 dark:hover:text-gray-100 focus:outline-none focus:bg-gray-100 dark:focus:bg-gray-900 focus:text-gray-900 dark:focus:text-gray-100"
            role="menuitem"
          >
            View All
          </a>
        </React.Fragment>
      )
    }
  }

  render() {
    const hoverClass = this.props.loggedIn
      ? 'hover:text-gray-500 dark:hover:text-gray-200 focus:border-blue-300 focus:ring '
      : 'cursor-default'

    return (
      <div
        className={classNames(
          'relative inline-block text-left shrink-0',
          this.props.className
        )}
      >
        <button
          ref={this.siteSwitcherButton}
          className={`inline-flex items-center rounded-md h-9 leading-5 font-bold text-gray-700 dark:text-gray-300 focus:outline-none transition ease-in-out duration-150 ${hoverClass}`}
        >
          <Favicon
            domain={this.props.site.domain}
            className="w-4 align-middle"
          />
          <span className="hidden sm:inline-block ml-2">
            {this.props.site.domain}
          </span>
          {this.props.loggedIn && (
            <ChevronDownIcon className="ml-2 h-5 w-5 shrink-0 hidden sm:inline-block" />
          )}
        </button>

        <Transition
          show={this.state.open}
          enter="transition ease-out duration-100"
          enterFrom="opacity-0 scale-95"
          enterTo="opacity-100 scale-100"
          leave="transition ease-in duration-75"
          leaveFrom="opacity-100 scale-100"
          leaveTo="opacity-0 scale-95"
        >
          <div
            className="origin-top-left absolute left-0 mt-2 w-64 rounded-md shadow-lg z-10"
            ref={(node) => (this.dropDownNode = node)}
          >
            <div className="rounded-md bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5">
              {this.renderDropdown()}
            </div>
          </div>
        </Transition>
      </div>
    )
  }
}
