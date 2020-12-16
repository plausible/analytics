import React from 'react';

export const withPinnedHeader = (WrappedComponent, flagName) => {
  return class extends React.Component {
    constructor(props) {
      super(props)
      this.state = {
        pinned: (window.localStorage[`pinned__${flagName}`] || 'true') === 'true',
        stuck: false
      }

      this.togglePinned = this.togglePinned.bind(this);
    }

    togglePinned() {
      this.setState(
        (state) => ({ pinned: !state.pinned })
      );
    }

    componentDidMount() {
      this.observer = new IntersectionObserver((entries) => {
        if (entries[0].intersectionRatio === 0)
          this.setState({ stuck: true });
        else if (entries[0].intersectionRatio === 1)
          this.setState({ stuck: false });
      }, {
        threshold: [0, 1]
      });

      this.observer.observe(document.querySelector("#stats-container-top"));
    }

    componentDidUpdate(prevProps, prevState) {
      if (prevState.pinned !== this.state.pinned) {
        window.localStorage[`pinned__${flagName}`] = this.state.pinned;
      }
    }

    componentWillUnmount() {
      this.observer.unobserve(document.querySelector("#stats-container-top"));
    }

    render() {
      const { pinned, stuck } = this.state;
      return (
        <WrappedComponent pinned={pinned} stuck={stuck} togglePinned={this.togglePinned} {...this.props}/>
      );
    }
  }
}
