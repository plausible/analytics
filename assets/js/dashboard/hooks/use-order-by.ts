import { useCallback, useEffect, useMemo, useState } from 'react'
import { isSortable, Metric } from '../stats/metrics'
import { getDomainScopedStorageKey, getItem, setItem } from '../util/storage'
import { useSiteContext } from '../site-context'

export enum SortDirection {
  asc = 'asc',
  desc = 'desc'
}

export type Order = [string, SortDirection]

export type OrderBy = Order[]

export const getSortDirectionLabel = (sortDirection: SortDirection): string =>
  ({
    [SortDirection.asc]: 'Sorted in ascending order',
    [SortDirection.desc]: 'Sorted in descending order'
  })[sortDirection]

export function useOrderBy({
  metrics,
  defaultOrderBy
}: {
  metrics: Metric[]
  defaultOrderBy: OrderBy
}) {
  const [orderBy, setOrderBy] = useState<OrderBy>([])
  const orderByDictionary = useMemo(
    () =>
      (orderBy.length
        ? Object.fromEntries(orderBy)
        : Object.fromEntries(defaultOrderBy)),
    [orderBy, defaultOrderBy]
  )

  const toggleSortByMetric = useCallback(
    (metric: Metric) => {
      if (!metrics.find((m) => m === metric)) {
        return
      }
      setOrderBy((currentOrderBy) =>
        rearrangeOrderBy(
          currentOrderBy.length ? currentOrderBy : defaultOrderBy,
          metric
        )
      )
    },
    [metrics, defaultOrderBy]
  )

  return {
    orderBy: orderBy.length ? orderBy : defaultOrderBy,
    orderByDictionary,
    toggleSortByMetric
  }
}

export function cycleSortDirection(
  currentSortDirection: SortDirection | null
): { direction: SortDirection; hint: string } {
  if (currentSortDirection === SortDirection.desc) {
    return {
      direction: SortDirection.asc,
      hint: 'Press to sort column in ascending order'
    }
  }

  return {
    direction: SortDirection.desc,
    hint: 'Press to sort column in descending order'
  }
}

export function rearrangeOrderBy(
  currentOrderBy: OrderBy,
  metric: Metric
): OrderBy {
  const orderIndex = currentOrderBy.findIndex(([m]) => m === metric)
  if (orderIndex < 0) {
    const sortDirection = cycleSortDirection(null).direction as SortDirection
    return [[metric, sortDirection]]
  }
  const previousOrder = currentOrderBy[orderIndex]
  const sortDirection = cycleSortDirection(previousOrder[1]).direction
  if (sortDirection === null) {
    return []
  }
  return [[metric, sortDirection]]
}

export function getOrderByStorageKey(domain: string, dimensionLabel: string) {
  const storageKey = getDomainScopedStorageKey(
    `order_${dimensionLabel}_by`,
    domain
  )
  return storageKey
}

export function validateOrderBy(
  orderBy: unknown,
  metrics: Metric[]
): orderBy is OrderBy {
  if (!Array.isArray(orderBy)) {
    return false
  }
  if (orderBy.length !== 1) {
    return false
  }
  if (!Array.isArray(orderBy[0])) {
    return false
  }
  if (
    orderBy[0].length === 2 &&
    metrics.findIndex((m) => m === orderBy[0][0]) > -1 &&
    [SortDirection.asc, SortDirection.desc].includes(orderBy[0][1])
  ) {
    return true
  }
  return false
}

export function getStoredOrderBy({
  domain,
  dimensionLabel,
  metrics,
  fallbackValue
}: {
  domain: string
  dimensionLabel: string
  metrics: Metric[]
  fallbackValue: OrderBy
}): OrderBy {
  try {
    const storedItem = getItem(getOrderByStorageKey(domain, dimensionLabel))
    const parsed = JSON.parse(storedItem)
    if (
      validateOrderBy(
        parsed,
        metrics.filter((m) => isSortable(m))
      )
    ) {
      return parsed
    } else {
      throw new Error('Invalid stored order_by value')
    }
  } catch (_e) {
    return fallbackValue
  }
}

export function maybeStoreOrderBy({
  domain,
  dimensionLabel,
  metrics,
  orderBy
}: {
  domain: string
  dimensionLabel: string
  metrics: Metric[]
  orderBy: OrderBy
}) {
  if (
    validateOrderBy(
      orderBy,
      metrics.filter((m) => isSortable(m))
    )
  ) {
    setItem(
      getOrderByStorageKey(domain, dimensionLabel),
      JSON.stringify(orderBy)
    )
  }
}

export function useRememberOrderBy({
  effectiveOrderBy,
  metrics,
  dimensionLabel
}: {
  effectiveOrderBy: OrderBy
  metrics: Metric[]
  dimensionLabel: string
}) {
  const site = useSiteContext()

  useEffect(() => {
    maybeStoreOrderBy({
      domain: site.domain,
      metrics,
      dimensionLabel,
      orderBy: effectiveOrderBy
    })
  }, [site, dimensionLabel, effectiveOrderBy, metrics])
}
