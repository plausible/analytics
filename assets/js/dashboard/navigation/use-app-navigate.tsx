/* @format */
import React, { forwardRef, useCallback } from 'react'
import {
  Link,
  useLocation,
  useNavigate,
  generatePath,
  Params,
  NavigateOptions,
  LinkProps
} from 'react-router-dom'
import { parseSearch, stringifySearch } from '../util/url-search-params'

export type AppNavigationTarget = {
  /**
   * path to target, for example `"/posts"` or `"/posts/:id"`
   */
  path?: string
  /**
   * dictionary of param keys with their values, if needed, for example `{ id: "some-id" }`
   */
  params?: Params
  /**
   * function in the form of `(currentSearchRecord) => newSearchRecord` to set link search value, for example
   * - `(s) => s` preserves current search value,
   * - `(s) => ({ ...s, calendar: !s.calendar })` toggles the value for calendar search parameter,
   * - `() => ({ page: 5 })` sets the search to `?page=5`,
   * - `undefined` empties the search
   */
  search?: (search: Record<string, unknown>) => Record<string, unknown>
}

const getNavigateToOptions = (
  currentSearchString: string,
  { path, params, search }: AppNavigationTarget
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
  const getToOptions = useCallback(
    ({ path, params, search }: AppNavigationTarget) => {
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
    ({
      path,
      params,
      search,
      ...options
    }: AppNavigationTarget & NavigateOptions) => {
      return _navigate(getToOptions({ path, params, search }), options)
    },
    [getToOptions, _navigate]
  )
  return navigate
}

export type AppNavigationLinkProps = AppNavigationTarget & Omit<LinkProps, 'to'>

export const AppNavigationLink = forwardRef<
  HTMLAnchorElement | null,
  AppNavigationLinkProps
>(({ path, params, search, ...options }, ref) => {
  const getToOptions = useGetNavigateOptions()

  return (
    <Link to={getToOptions({ path, params, search })} {...options} ref={ref} />
  )
})

AppNavigationLink.displayName = 'AppNavigationLink'
