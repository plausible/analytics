import React from 'react';
import { ComparisonContext } from './comparison-context'
import * as storage from './util/storage'


export const withComparisonProvider = (WrappedComponent) => {
  return class extends React.Component {
    constructor(props) {
      super(props)
      this.state = {
        comparison: {
          enabled: storage.getItem('comparison__enabled')=='true' || false,
          // timePeriod: storage.getItem('comparison__period') || ''
        }
      };

      this.updateComparisonData = this.updateComparisonData.bind(this)
    }

    updateComparisonData(data) {
      const {enabled} = data

      storage.setItem('comparison__enabled', enabled || false)

      this.setState({comparison: data})
    }

    render() {
      return (
        <ComparisonContext.Provider value={{data: this.state.comparison, modifyComparison: this.updateComparisonData}}>
          <WrappedComponent {...this.props}/>
        </ComparisonContext.Provider>
      );
    }
  }
}
