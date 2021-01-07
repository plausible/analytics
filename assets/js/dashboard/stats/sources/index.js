import React from 'react';
import SearchTerms from './search-terms';
import SourceList from './source-list';
import ReferrerList from './referrer-list';

export default function Sources(props) {
  if (props.query.filters.source === 'Google') {
    return <SearchTerms {...props} />;
  }
  if (props.query.filters.source) {
    return <ReferrerList {...props} />;
  }
  return <SourceList {...props} />;
}
