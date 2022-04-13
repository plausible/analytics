import React from 'react';
import { ComparisonContext } from './comparison-context'

export const withComparisonConsumer = (WrappedComponent) => {
  return class extends React.Component {
    render() {
      return (
        <ComparisonContext.Consumer>
          {({data, modifyComparison}) => (
            <WrappedComponent comparison={data} modifyComparison={modifyComparison} {...this.props} />
          )}
        </ComparisonContext.Consumer>
      );
    }
  }
}
