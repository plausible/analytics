import React from 'react';

export const ComparisonContext = React.createContext({
  data: {
    enabled: false,
    // timePeriod: '' // Saved for future update to allow for customizable compare period
  },
  modifyComparison: () => {}
});
