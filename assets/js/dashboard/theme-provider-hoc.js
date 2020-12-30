import React from 'react';
import { ThemeContext } from './theme-context'

export const withThemeProvider = (WrappedComponent) => {
  return class extends React.Component {
    constructor(props) {
      super(props)
      this.state = {
        dark: document.querySelector('html').classList.contains('dark') || false
      };

      this.mutationObserver = new MutationObserver((mutationsList, observer) => {
        mutationsList.forEach(mutation => {
          if (mutation.attributeName === 'class') {
            this.setState({ dark: mutation.target.classList.contains('dark') });
          }
        });
      });
    }

    componentDidMount() {
      this.mutationObserver.observe(document.querySelector('html'), { attributes: true });
    }

    componentWillUnmount() {
      this.mutationObserver.disconnect();
    }

    render() {
      return (
        <ThemeContext.Provider value={this.state.dark}>
          <WrappedComponent {...this.props}/>
        </ThemeContext.Provider>
      );
    }
  }
}
