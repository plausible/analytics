import React from 'react';

export const withPinnedHeader = (WrappedComponent, flagName) => {
  return class extends React.Component {
    constructor(props) {
      super(props)
      this.state = {
        stuck: false
      }
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

    componentWillUnmount() {
      this.observer.unobserve(document.querySelector("#stats-container-top"));
    }

    render() {
      return (
        <WrappedComponent stuck={this.state.stuck}{...this.props}/>
      );
    }
  }
}
