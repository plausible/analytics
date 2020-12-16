import React from 'react';
import { ThemeContext } from './theme-context'

export const withThemeConsumer = (WrappedComponent) => {
  return class extends React.Component {
    render() {
      return (
        <ThemeContext.Consumer>
          {theme => (
            <WrappedComponent darkTheme={theme} {...this.props} />
          )}
        </ThemeContext.Consumer>
      );
    }
  }
}
