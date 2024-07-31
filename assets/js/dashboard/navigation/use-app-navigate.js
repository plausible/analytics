import React, { forwardRef, useCallback } from 'react'
import { Link, useLocation, useNavigate, generatePath } from 'react-router-dom'
import { parseSearch, stringifySearch } from '../util/url'

const getNavigateToOptions = (
  currentSearchString,
  { path, params, search }
) => {
  const searchRecord = parseSearch(currentSearchString)
  const updatedSearchRecord = search && search(searchRecord)
  const updatedPath = path && generatePath(path, params)
  return {
    pathname: updatedPath,
    search: updatedSearchRecord && stringifySearch(updatedSearchRecord)
  }
}

export const useGetNavigateOptions = () => {
  const location = useLocation()
  /**
   * @param path - path to target, for example `"/posts"` or `"/posts/:id"`
   * @param params - dictionary of param keys with their values, if needed, for example `{ id: "some-id" }`
   * @param search -
   *   function in the form of `(currentSearchRecord) => newSearchRecord` to set link search value, for example
   *  `(s) => s` preserves current search value,
   *  `() => ({page: 5})` sets the search to `?page=5`,
   *  `undefined` empties the search
   * @returns the appropriate value for `react-router-dom` `Link` and `navigate` `to` property
   */
  const getToOptions = useCallback(
    ({ path, params, search }) => {
      return getNavigateToOptions(location.search, { path, params, search })
    },
    [location.search]
  )
  return getToOptions
}

export const useAppNavigate = () => {
  const _navigate = useNavigate()
  const getToOptions = useGetNavigateOptions()
  const navigate = useCallback(
    ({ path, params, search, ...options }) => {
      return _navigate(getToOptions({ path, params, search }), options)
    },
    [getToOptions, _navigate]
  )
  return navigate
}

export const AppNavigationLink = forwardRef(
  ({ path, params, search, ...options }, ref) => {
    const getToOptions = useGetNavigateOptions()

    return (
      <Link
        to={getToOptions({ path, params, search })}
        {...options}
        ref={ref}
      />
    )
  }
)

AppNavigationLink.displayName = 'AppNavigationLink'
