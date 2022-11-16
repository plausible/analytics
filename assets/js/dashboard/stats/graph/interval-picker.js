import { Transition } from '@headlessui/react';
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import React, { Component, Fragment } from 'react';

export const INTERVAL_MAPPING = {
  'realtime': ['minute'],
  'day': ['minute', 'hour'],
  '7d': ['hour', 'date'],
  'month': ['date', 'week'],
  '30d': ['date', 'week'],
  '6mo': ['date', 'week', 'month'],
  '12mo': ['date', 'week', 'month'],
  'year': ['date', 'week', 'month'],
  'all': ['date', 'week', 'month'],
  'custom': ['date', 'week', 'month']
}

export const INTERVAL_LABELS = {
  'minute': 'Minutes',
  'hour': 'Hours',
  'date': 'Days',
  'week': 'Weeks',
  'month': 'Months'
}

export default class IntervalPicker extends Component {
  constructor(props) {
    super(props);
    this.state = {
      open: false
    };

    this.handleClick = this.handleClick.bind(this);
    this.renderDropDownContent = this.renderDropDownContent.bind(this);
  }

  componentDidMount() {
    document.addEventListener("mousedown", this.handleClick);
  }

  componentWillUnmount() {
    document.removeEventListener("mousedown", this.handleClick);
  }

  handleClick(e) {
    if (this.dropDownNode && this.dropDownNode.contains(e.target)) return;

    this.setState({ open: false });
  }

  renderDropDownContent() {
    const { query, graphData } = this.props

    const currentInterval = (graphData && graphData.interval) || query.interval;

    return (
      <div
        id="intervalmenu"
        className="absolute w-56 sm:w-42 md:w-56 md:absolute right-0 mt-2 z-10"
      >
        <div
          className="rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5
          font-medium text-gray-800 dark:text-gray-200"
        >
          <div className="py-1">
            {INTERVAL_MAPPING[query.period].length > 1 && INTERVAL_MAPPING[query.period].map(interval => (
              currentInterval === interval ?
                (
                  <div key={interval} className="font-bold px-4 py-2 text-sm leading-tight hover:bg-gray-100 hover:text-gray-900 dark:hover:bg-gray-900 dark:hover:text-gray-100 flex items-center justify-between">
                    {INTERVAL_LABELS[interval]}
                  </div>
                ) : (
                  <a
                    onClick={() => {this.props.updateInterval(interval); this.setState({ open: false })}}
                    key={interval}
                    className="px-4 py-2 text-sm leading-tight hover:bg-gray-100 hover:text-gray-900
                  dark:hover:bg-gray-900 dark:hover:text-gray-100 flex items-center justify-between cursor-pointer"
                  >
                    {INTERVAL_LABELS[interval]}
                  </a>
                )
            ))}
          </div>
        </div>
      </div>
    );
  }

  render() {
    const { query, metric, graphData } = this.props;

    if (query.period === 'realtime') return null;

    return (
      <Transition
        show={!!(metric && graphData)}
        as={Fragment}
        enter="transition ease-out duration-75"
        enterFrom="transform opacity-0 scale-95"
        enterTo="transform opacity-100 scale-100"
        leave="transition ease-in duration-75"
        leaveFrom="transform opacity-100 scale-100"
        leaveTo="transform opacity-0 scale-95"
      >
        <div ref={node => this.dropDownNode = node}>
          <button
            className="text-sm font-normal text-gray-900 cursor-pointer text-gray-500 dark:text-gray-200 hover:text-indigo-700 dark:hover:text-indigo-500 inline-flex items-center"
            onClick={() => this.setState((state) => ({ open: !state.open }))}
            onKeyPress={() => this.setState((state) => ({ open: !state.open }))}
            aria-haspopup="true"
            aria-expanded="false"
            aria-controls="intervalmenu"
            title="Choose the interval to display on each step of the graph"
          >
            <span>Graph detail</span>
            <ChevronDownIcon className="h-5 w-5" />
          </button>
          <Transition
            show={this.state.open}
            as={Fragment}
            enter="transition ease-out duration-100"
            enterFrom="transform opacity-0 scale-95"
            enterTo="transform opacity-100 scale-100"
            leave="transition ease-in duration-75"
            leaveFrom="transform opacity-100 scale-100"
            leaveTo="transform opacity-0 scale-95"
          >
            {this.renderDropDownContent()}
          </Transition>
        </div>
      </Transition>
    )
  }
}
