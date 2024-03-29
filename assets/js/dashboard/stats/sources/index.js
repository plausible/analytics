import React from 'react';
import SearchTerms from './search-terms'
import SourceList from './source-list'
import ReferrerList from './referrer-list'
import { isFilteringOnFixedValue } from '../../util/filters'


export default function Sources(props) {
  if (props.query.filters.source === 'Google') {
    return <SearchTerms {...props} />
  } else if (isFilteringOnFixedValue(props.query, 'source')) {
    return <ReferrerList {...props} />
  } else  {
    return <SourceList {...props} />
  }
}
