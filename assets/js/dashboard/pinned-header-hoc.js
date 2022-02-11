import React from 'react';

export const withPinnedHeader = (WrappedComponent, selector) => {
  return class extends React.Component {
    constructor(props) {
      super(props)
      this.state = {
        stuck: false
      }
    }

    componentDidMount() {
      if ('IntersectionObserver' in window) {
        this.attachObserver()
      }
    }

    attachObserver() {
      this.observer = new IntersectionObserver((entries) => {
        if (entries[0].intersectionRatio === 0)
          this.setState({ stuck: true });
        else if (entries[0].intersectionRatio === 1)
          this.setState({ stuck: false });
      }, {
        threshold: [0, 1]
      });

      this.el = document.querySelector(selector)
      this.observer.observe(this.el);
    }

    componentWillUnmount() {
      this.observer && this.observer.unobserve(this.el);
    }

    render() {
      return (
        <WrappedComponent stuck={this.state.stuck}{...this.props}/>
      );
    }
  }
}
