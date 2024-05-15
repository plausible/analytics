import React from 'react'
import RocketIcon from './modals/rocket-icon'
import { BarsArrowUpIcon } from '@heroicons/react/20/solid'

/*
This function checks whether the current set of query filters supports
imported data. It expects a `children` prop with any report contents
which will be rendered if the conditions are satisfied.

Given that `query.with_imported` is false, the children will simply be
rendered. Otherwise, the filters (and the breakdown property) will be
checked against the following rules:

1) Special custom props `url` and `path` require their corresponding
   special goal filter

2) Only a single property can be filtered by

3) If a breakdown property is given (i.e. it's not an aggregate or
   timeseries query), then it has to match with the property that is
   filtered by. Only exception is the `url` or `path` breakdown, in
   which case a goal filter is *required*

If any of these rules is violated, an error message will be displayed
to the user, instead of the actual report contents.
*/
export default function ImportedQueryValidationBoundary({property, query, children, classNames}) {
  console.log(query.filters)
  const propsInFilter = Object.keys(query.filters)
    .filter(filter_key => query.filters[filter_key])

  let isSupportedFilterSet

  if (!query.with_imported) {
    isSupportedFilterSet = true
  }
  else if (propsInFilter.length === 0) {
    isSupportedFilterSet = true
  }
  else if (propsInFilter.length === 1) {
    isSupportedFilterSet = property === propsInFilter[0]
  }
  else {
    isSupportedFilterSet = false
  }
    
  if (isSupportedFilterSet) {
    return children
  } else {
    return (
      <div className={`text-center text-gray-700 dark:text-gray-300 text-sm ${classNames}`}>
        <RocketIcon />
        <p>
          We're unable to show this report based on imported data with the current set of filters. Find the
          <BarsArrowUpIcon className={"mx-1 inline w-5 h-5 dark:text-gray-300 text-gray-700"} />
          icon above the graph to switch to native data only.
        </p>
      </div>
    )
  }
}