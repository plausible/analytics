import React from 'react';
import RocketIcon from './stats/modals/rocket-icon'

export default class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = {error: null}
  }

  static getDerivedStateFromError(error) {
    return {error: error}
  }

  render() {
    if (this.state.error) {
      return (
        <div className="text-center text-gray-900 dark:text-gray-100 mt-36">
          <RocketIcon />
          <div className="text-lg font-bold">Oops! Something went wrong</div>
          <div className="text-lg">{this.state.error.name + ': ' + this.state.error.message}</div>
        </div>
      )
    }
    return this.props.children;
  }
}
