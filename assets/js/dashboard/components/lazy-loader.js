import React from 'react';

export default class extends React.Component {
  componentDidMount() {
    this.observer = new IntersectionObserver((entries) => {
      if (entries[0].isIntersecting) {
        this.props.onVisible && this.props.onVisible()
        this.observer.unobserve(this.element);
      }
    }, {
      threshold: 0
    });

    this.observer.observe(this.element);
  }

  componentWillUnmount() {
    this.observer.unobserve(this.element);
  }

  render() {
    return (
      <div
        ref={(el) => { this.element = el }}
        className={this.props.className}
        style={this.props.style}
      >
        {this.props.children}
      </div>
    );
  }
}
