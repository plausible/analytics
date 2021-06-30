import React from 'react';
import { withRouter, Link } from 'react-router-dom'
import { countFilters, formattedFilters, navigateToQuery } from './query'
import { filterGroupForFilter } from './stats/modals/filter'
import Datamap from 'datamaps'
import Transition from "../transition.js";

class Filters extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      dropdownOpen: false,
      wrapped: 1, // 0=unwrapped, 1=waiting to check, 2=wrapped
      viewport: 1080
    };

    this.appliedFilters = Object.keys(props.query.filters)
      .map((key) => [key, props.query.filters[key]])
      .filter(([key, value]) => !!value);

    this.renderDropDown = this.renderDropDown.bind(this);
    this.renderDropDownContent = this.renderDropDownContent.bind(this);
    this.handleClick = this.handleClick.bind(this);
    this.handleResize = this.handleResize.bind(this);
    this.rewrapFilters = this.rewrapFilters.bind(this);
    this.renderFilterList = this.renderFilterList.bind(this);
    this.handleKeyup = this.handleKeyup.bind(this)
  }

  componentDidMount() {
    document.addEventListener('mousedown', this.handleClick, false);
    window.addEventListener('resize', this.handleResize, false);
    document.addEventListener('keyup', this.handleKeyup);

    this.rewrapFilters();
    this.handleResize();
  }

  componentDidUpdate(prevProps, prevState) {
    const { query } = this.props;
    const { viewport, wrapped } = this.state;

    this.appliedFilters = Object.keys(query.filters)
      .map((key) => [key, query.filters[key]])
      .filter(([key, value]) => !!value)

    if (JSON.stringify(query) !== JSON.stringify(prevProps.query) || viewport !== prevState.viewport) {
      this.setState({ wrapped: 1 });
    }

    if (wrapped === 1 && prevState.wrapped !== 1) {
      this.rewrapFilters();
    }
  }

  componentWillUnmount() {
    document.removeEventListener("keyup", this.handleKeyup);
    document.removeEventListener('mousedown', this.handleClick, false);
    window.removeEventListener('resize', this.handleResize, false);
  }

  handleKeyup(e) {
    const { query, history } = this.props

    if (e.ctrlKey || e.metaKey || e.altKey) return

    if (e.key === 'Escape') {
      this.clearAllFilters(history, query)
    }
  }

  handleResize() {
    this.setState({ viewport: window.innerWidth || 639 });
  }

  handleClick(e) {
    if (this.dropDownNode && this.dropDownNode.contains(e.target)) return;

    this.setState({ dropdownOpen: false });
  };

  // Checks if the filter container is wrapping items
  rewrapFilters() {
    let currItem, prevItem, items = document.getElementById('filters');
    const { wrapped } = this.state;

    this.setState({ wrapped: 0 });

    // Don't rewrap if we're already properly wrapped, there are no DOM children, or there is only filter
    if (wrapped !== 1 || !items || this.appliedFilters.length === 1) {
      return;
    };

    // For every filter DOM Node, check if its y value is higher than the previous (this indicates a wrap)
    [...(items.childNodes)].forEach(item => {
      currItem = item.getBoundingClientRect();
      if (prevItem && prevItem.top < currItem.top) {
        this.setState({ wrapped: 2 });
      }
      prevItem = currItem;
    });
  };

  filterText(key, value, query) {
    const negated = value[0] == '!' && ['page', 'entry_page', 'exit_page'].includes(key)
    value = negated ? value.slice(1) : value

    if (key === "goal") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Completed goal <b>{value}</b></span>
    }
    if (key === "props") {
      const [metaKey, metaValue] = Object.entries(value)[0]
      const eventName = query.filters["goal"] ? query.filters["goal"] : 'event'
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">{eventName}.{metaKey} is <b>{metaValue}</b></span>
    }
    if (key === "source") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Source is <b>{value}</b></span>
    }
    if (key === "utm_medium") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">UTM medium is <b>{value}</b></span>
    }
    if (key === "utm_source") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">UTM source is <b>{value}</b></span>
    }
    if (key === "utm_campaign") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">UTM campaign is <b>{value}</b></span>
    }
    if (key === "referrer") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Referrer URL is <b>{value}</b></span>
    }
    if (key === "screen") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Screen size is <b>{value}</b></span>
    }
    if (key === "browser") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Browser is <b>{value}</b></span>
    }
    if (key === "browser_version") {
      const browserName = query.filters["browser"] ? query.filters["browser"] : 'Browser'
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">{browserName} Version is <b>{value}</b></span>
    }
    if (key === "os") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Operating System is <b>{value}</b></span>
    }
    if (key === "os_version") {
      const osName = query.filters["os"] ? query.filters["os"] : 'OS'
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">{osName} Version is <b>{value}</b></span>
    }
    if (key === "country") {
      const allCountries = Datamap.prototype.worldTopo.objects.world.geometries;
      const selectedCountry = allCountries.find((c) => c.id === value) || { properties: { name: value } };
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Country is <b>{selectedCountry.properties.name}</b></span>
    }
    if (key === "page") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Page is{negated ? ' not' : ''} <b>{value}</b></span>
    }
    if (key === "entry_page") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Entry Page is{negated ? ' not' : ''} <b>{value}</b></span>
    }
    if (key === "exit_page") {
      return <span className="inline-block max-w-2xs md:max-w-xs truncate">Exit Page is{negated ? ' not' : ''} <b>{value}</b></span>
    }
  }

  removeFilter(key, history, query) {
    const newOpts = {
      [key]: false
    }
    if (key === 'goal') { newOpts.props = false }
    navigateToQuery(
      history,
      query,
      newOpts
    )
  }

  renderDropdownFilter(history, [key, value], query) {
    if ('props' == key) {
      return (
        <div className="px-4 sm:py-2 py-3 md:text-sm leading-tight flex items-center justify-between" key={key + value}>
          {this.filterText(key, value, query)}
          <b title={`Remove filter: ${formattedFilters[key]}`} className="ml-2 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500" onClick={() => this.removeFilter(key, history, query)}>✕</b>
        </div>
      )
    }

    return (
      <div className="px-3 md:px-4 sm:py-2 py-3 md:text-sm leading-tight flex items-center justify-between" key={key + value}>
        <Link
          title={`Edit filter: ${formattedFilters[key]}`}
          to={{ pathname: `/${encodeURIComponent(this.props.site.domain)}/filter/${filterGroupForFilter(key)}`, search: window.location.search }}
          className="group flex w-full justify-between items-center"
        >
          {this.filterText(key, value, query)}
          <svg className="ml-1 cursor-pointer group-hover:text-indigo-700 dark:group-hover:text-indigo-500 w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
        </Link>
        <b title={`Remove filter: ${formattedFilters[key]}`} className="ml-2 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500" onClick={() => this.removeFilter(key, history, query)}>✕</b>
      </div>
    )
  }

  renderListFilter(history, [key, value], query) {
    return (
      <span key={key} title={value} className="flex bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 shadow text-sm rounded mr-2 items-center">
        {'props' == key ? (
          <span className="flex w-full h-full items-center py-2 pl-3">
            {this.filterText(key, value, query)}
          </span>
        ) : (
          <>
            <Link title={`Edit filter: ${formattedFilters[key]}`} className="filter-list-text flex w-full h-full items-center py-2 pl-3" to={{ pathname: `/${encodeURIComponent(this.props.site.domain)}/filter/${filterGroupForFilter(key)}`, search: window.location.search }}>
              {this.filterText(key, value, query)}
            </Link>
            <span className="filter-list-edit hidden h-full w-full px-2 cursor-pointer text-indigo-700 dark:text-indigo-500 items-center">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="1 1 23 23" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
            </span>
          </>
        )}
        <span title={`Remove filter: ${formattedFilters[key]}`} className="filter-list-remove flex h-full w-full px-2 cursor-pointer hover:text-indigo-700 dark:hover:text-indigo-500 items-center" onClick={() => this.removeFilter(key, history, query)}>
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12"></path></svg>
        </span>
      </span>
    )
  }

  clearAllFilters(history, query) {
    const newOpts = Object.keys(query.filters).reduce((acc, red) => ({ ...acc, [red]: false }), {});
    navigateToQuery(
      history,
      query,
      newOpts
    );
  }

  renderDropDownContent() {
    const { viewport } = this.state;
    const { history, query, site } = this.props;

    return (
      <div className="absolute mt-2 rounded shadow-md z-10" style={{ width: viewport <= 768 ? '320px' : '350px', right: '-5px' }} ref={node => this.dropDownNode = node}>
        <div className="rounded bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 font-medium text-gray-800 dark:text-gray-200 flex flex-col">
          <Link to={`/${encodeURIComponent(site.domain)}/filter${window.location.search}`} className="group border-b flex border-gray-200 dark:border-gray-500 px-4 sm:py-2 py-3 md:text-sm leading-tight hover:text-indigo-700 dark:hover:text-indigo-500 hover:cursor-pointer">
            <svg className="mr-2 h-4 w-4 text-gray-500 dark:text-gray-200 group-hover:text-indigo-700 dark:group-hover:text-indigo-500 hover:cursor-pointer" fill="none" stroke="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path></svg>
            Add Filter
          </Link>
          {this.appliedFilters.map((filter) => this.renderDropdownFilter(history, filter, query))}
          <div className="border-t border-gray-200 dark:border-gray-500 px-4 sm:py-2 py-3 md:text-sm leading-tight hover:text-indigo-700 dark:hover:text-indigo-500 hover:cursor-pointer" onClick={() => this.clearAllFilters(history, query)}>
            Clear All Filters
          </div>
        </div>
      </div>
    )
  }

  renderDropDown() {
    return (
      <div id="filters" className='ml-auto'>
        <div className="relative" style={{ height: '35.5px', width: '100px' }}>
          <div onClick={() => this.setState((state) => ({ dropdownOpen: !state.dropdownOpen }))} className="flex items-center justify-between rounded bg-white dark:bg-gray-800 shadow px-4 pr-3 py-2 leading-tight cursor-pointer text-sm font-medium text-gray-800 dark:text-gray-200 h-full">
            <span className="mr-2">Filters</span>
            <svg className="text-indigo-500 h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <polyline points="6 9 12 15 18 9"></polyline>
            </svg>
          </div>
          <Transition
            show={this.state.dropdownOpen}
            enter="transition ease-out duration-100 transform"
            enterFrom="opacity-0 scale-95"
            enterTo="opacity-100 scale-100"
            leave="transition ease-in duration-75 transform"
            leaveFrom="opacity-100 scale-100"
            leaveTo="opacity-0 scale-95"
          >
            {this.renderDropDownContent()}
          </Transition>
        </div>
      </div>
    );
  }

  renderFilterList() {
    const { history, query, site } = this.props;

    return (
      <div id="filters" className="flex flex-grow pl-2 flex-wrap">
        {(this.appliedFilters.map((filter) => this.renderListFilter(history, filter, query)))}

        <Link to={`/${encodeURIComponent(site.domain)}/filter${window.location.search}`} className={`inline-flex items-center text-sm font-medium px-4 py-2 mr-2 cursor-pointer ml-auto text-gray-500 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-900 rounded`}>
          <svg className="mr-1 w-4 h-4" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M5 4a1 1 0 00-2 0v7.268a2 2 0 000 3.464V16a1 1 0 102 0v-1.268a2 2 0 000-3.464V4zM11 4a1 1 0 10-2 0v1.268a2 2 0 000 3.464V16a1 1 0 102 0V8.732a2 2 0 000-3.464V4zM16 3a1 1 0 011 1v7.268a2 2 0 010 3.464V16a1 1 0 11-2 0v-1.268a2 2 0 010-3.464V4a1 1 0 011-1z"></path></svg>
          Filter
        </Link>

      </div>
    );
  }

  render() {
    const { wrapped, viewport } = this.state;

    if (this.appliedFilters.length > 0 && (wrapped === 2 || viewport <= 768)) {
      return this.renderDropDown();
    }

    return this.renderFilterList();
  }
}

export default withRouter(Filters);
