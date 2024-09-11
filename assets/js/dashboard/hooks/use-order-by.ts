/** @format */

import { useCallback, useEffect, useMemo, useState } from 'react'
import { Metric } from '../stats/reports/metrics'
import { getDomainScopedStorageKey, getItem, setItem } from '../util/storage'
import { useSiteContext } from '../site-context'
import { ReportInfo } from '../stats/modals/breakdown-modal'

export enum SortDirection {
  asc = 'asc',
  desc = 'desc'
}

export type Order = [Metric['key'], SortDirection]

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
  metrics: Pick<Metric, 'key'>[]
  defaultOrderBy: OrderBy
}) {
  const [orderBy, setOrderBy] = useState<OrderBy>([])
  const orderByDictionary: Record<Metric['key'], SortDirection> = useMemo(
    () =>
      orderBy.length
        ? Object.fromEntries(orderBy)
        : Object.fromEntries(defaultOrderBy),
    [orderBy, defaultOrderBy]
  )

  const toggleSortByMetric = useCallback(
    (metric: Pick<Metric, 'key'>) => {
      if (!metrics.find(({ key }) => key === metric.key)) {
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

export function findOrderIndex(orderBy: OrderBy, metric: Pick<Metric, 'key'>) {
  return orderBy.findIndex(([metricKey]) => metricKey === metric.key)
}

export function rearrangeOrderBy(
  currentOrderBy: OrderBy,
  metric: Pick<Metric, 'key'>
): OrderBy {
  const orderIndex = findOrderIndex(currentOrderBy, metric)
  if (orderIndex < 0) {
    const sortDirection = cycleSortDirection(null).direction as SortDirection
    return [[metric.key, sortDirection]]
  }
  const previousOrder = currentOrderBy[orderIndex]
  const sortDirection = cycleSortDirection(previousOrder[1]).direction
  if (sortDirection === null) {
    return []
  }
  return [[metric.key, sortDirection]]
}

export function getOrderByStorageKey(
  domain: string,
  reportInfo: Pick<ReportInfo, 'dimensionLabel'>
) {
  const storageKey = getDomainScopedStorageKey(
    `order_${reportInfo.dimensionLabel}_by`,
    domain
  )
  return storageKey
}

export function validateOrderBy(
  orderBy: unknown,
  metrics: Pick<Metric, 'key'>[]
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
    metrics.findIndex((m) => m.key === orderBy[0][0]) > -1 &&
    [SortDirection.asc, SortDirection.desc].includes(orderBy[0][1])
  ) {
    return true
  }
  return false
}

export function getStoredOrderBy({
  domain,
  reportInfo,
  metrics,
  fallbackValue
}: {
  domain: string
  reportInfo: Pick<ReportInfo, 'dimensionLabel'>
  metrics: Pick<Metric, 'key' | 'sortable'>[]
  fallbackValue: OrderBy
}): OrderBy {
  try {
    const storedItem = getItem(getOrderByStorageKey(domain, reportInfo))
    const parsed = JSON.parse(storedItem)
    if (
      validateOrderBy(
        parsed,
        metrics.filter((m) => m.sortable)
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
  reportInfo,
  metrics,
  orderBy
}: {
  domain: string
  reportInfo: Pick<ReportInfo, 'dimensionLabel'>
  metrics: Pick<Metric, 'key' | 'sortable'>[]
  orderBy: OrderBy
}) {
  if (
    validateOrderBy(
      orderBy,
      metrics.filter((m) => m.sortable)
    )
  ) {
    setItem(getOrderByStorageKey(domain, reportInfo), JSON.stringify(orderBy))
  }
}

export function useRememberOrderBy({
  effectiveOrderBy,
  metrics,
  reportInfo
}: {
  effectiveOrderBy: OrderBy
  metrics: Pick<Metric, 'key' | 'sortable'>[]
  reportInfo: Pick<ReportInfo, 'dimensionLabel'>
}) {
  const site = useSiteContext()

  useEffect(() => {
    maybeStoreOrderBy({
      domain: site.domain,
      metrics,
      reportInfo,
      orderBy: effectiveOrderBy
    })
  }, [site, reportInfo, effectiveOrderBy, metrics])
}
