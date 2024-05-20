import React from 'react';
import SearchTerms from './search-terms'
import SourceList from './source-list'
import ReferrerList from './referrer-list'
import { getFiltersByKeyPrefix, isFilteringOnFixedValue } from '../../util/filters'


export default function Sources(props) {
  if (isFilteringOnFixedValue(props.query, 'source', 'Google')) {
    return <SearchTerms {...props} />
  } else if (isFilteringOnFixedValue(props.query, 'source')) {
    const [[_operation, _filterKey, clauses]] = getFiltersByKeyPrefix(props.query, "source")
    return <ReferrerList {...props} source={clauses[0]} />
  } else  {
    return <SourceList {...props} />
  }
}
