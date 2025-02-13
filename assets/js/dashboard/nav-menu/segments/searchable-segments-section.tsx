/** @format */

import React, { useCallback, useEffect, useMemo, useState } from 'react'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import {
  formatSegmentIdAsLabelKey,
  getFilterSegmentsByNameInsensitive,
  isSegmentFilter,
  parseApiSegmentData,
  SavedSegment,
  SegmentData
} from '../../filtering/segments'
import { QueryFunction, useQuery, useQueryClient } from '@tanstack/react-query'
import { cleanLabels } from '../../util/filters'
import classNames from 'classnames'
import { Tooltip } from '../../util/tooltip'
import { useSegmentExpandedContext } from '../../segments/segment-expanded-context'
import { SegmentAuthorship } from '../../segments/segment-authorship'
import { SearchInput } from '../../components/search-input'
import { EllipsisHorizontalIcon } from '@heroicons/react/24/solid'
import { popover } from '../../components/popover'
import { AppNavigationLink } from '../../navigation/use-app-navigate'
import { MenuSeparator } from '../nav-menu-components'
import { ErrorPanel } from '../../components/error-panel'
import { get } from '../../api'

const useSegmentsListQuery = () => {
  const site = useSiteContext()
  const appliedSegmentIds = [] as number[]
  return useQuery({
    queryKey: ['segments'],
    placeholderData: (previousData) => previousData,
    queryFn: async () => {
      const response: SavedSegment[] = await get(
        `/api/${encodeURIComponent(site.domain)}/segments`
      )

      return response.sort(
        (a, b) =>
          appliedSegmentIds.findIndex((id) => id === b.id) -
          appliedSegmentIds.findIndex((id) => id === a.id)
      )
    }
  })
}

const linkClassName = classNames(
  popover.items.classNames.navigationLink,
  popover.items.classNames.selectedOption,
  popover.items.classNames.hoverLink,
  popover.items.classNames.groupRoundedStartEnd
)

const initialSliceLength = 5

export const SearchableSegmentsSection = ({
  closeList
}: {
  closeList: () => void
}) => {
  const { query } = useQueryContext()
  const segmentFilter = query.filters.find(isSegmentFilter)
  const appliedSegmentIds = (segmentFilter ? segmentFilter[2] : []) as number[]

  const { data, ...listQuery } = useSegmentsListQuery()
  const [searchValue, setSearch] = useState<string>()
  const [showAll, setShowAll] = useState(false)

  const searching = !searchValue?.trim().length

  useEffect(() => {
    setShowAll(false)
  }, [searching])

  const filteredData = data?.filter(
    getFilterSegmentsByNameInsensitive(searchValue)
  )

  const showableSlice = showAll
    ? filteredData
    : filteredData?.slice(0, initialSliceLength)

  const { expandedSegment } = useSegmentExpandedContext()

  if (expandedSegment) {
    return null
  }

  return (
    <>
      {!!data?.length && (
        <>
          <MenuSeparator />
          <div className="flex items-center pt-2 px-4 pb-2">
            <div className="text-sm font-bold uppercase text-indigo-500 dark:text-indigo-400 mr-4">
              Segments
            </div>
            {data.length > initialSliceLength && (
              <SearchInput
                placeholderUnfocused="Press / to search"
                className="ml-auto w-full py-1"
                onSearch={setSearch}
              />
            )}
          </div>

          {showableSlice!.map((s) => {
            return (
              <Tooltip
                className="group"
                key={s.id}
                info={
                  <div className="max-w-60">
                    <div className="break-all">{s.name}</div>
                    <div className="font-normal text-xs">
                      {
                        {
                          personal: 'Personal segment',
                          site: 'Site segment'
                        }[s.type]
                      }
                    </div>

                    <SegmentAuthorship {...s} className="font-normal text-xs" />
                  </div>
                }
              >
                <SegmentLink
                  {...s}
                  appliedSegmentIds={appliedSegmentIds}
                  closeList={closeList}
                />
              </Tooltip>
            )
          })}
          {!!filteredData?.length &&
            !!showableSlice?.length &&
            filteredData?.length > showableSlice?.length &&
            showAll === false && (
              <Tooltip className="group" info={null}>
                <AppNavigationLink
                  className={classNames(
                    linkClassName,
                    'font-bold hover:text-indigo-700 dark:hover:text-indigo-500'
                  )}
                  search={(s) => s}
                  onClick={() => setShowAll(true)}
                >
                  {`Show ${filteredData.length - showableSlice.length} more`}
                  <EllipsisHorizontalIcon className="block w-5 h-5" />
                </AppNavigationLink>
              </Tooltip>
            )}
        </>
      )}
      {listQuery.status === 'pending' && (
        <div className="p-4 flex justify-center items-center">
          <div className="loading sm">
            <div />
          </div>
        </div>
      )}
      {listQuery.error && (
        <div className="p-4">
          <ErrorPanel
            errorMessage="Loading segments failed"
            onRetry={() => listQuery.refetch()}
          />
        </div>
      )}
    </>
  )
}

export const useSegmentPrefetch = ({ id }: { id: string }) => {
  const site = useSiteContext()
  const queryClient = useQueryClient()
  const queryKey = useMemo(() => ['segments', id] as const, [id])

  const getSegmentFn: QueryFunction<
    SavedSegment & { segment_data: SegmentData },
    typeof queryKey
  > = useCallback(
    async ({ queryKey: [_, id] }) => {
      const res = await fetch(
        `/api/${encodeURIComponent(site.domain)}/segments/${id}`,
        {
          method: 'GET',
          headers: {
            'content-type': 'application/json',
            accept: 'application/json'
          }
        }
      )
      const d = await res.json()
      return {
        ...d,
        segment_data: parseApiSegmentData(d.segment_data)
      }
    },
    [site]
  )

  const getSegment = useQuery({
    enabled: false,
    queryKey: queryKey,
    queryFn: getSegmentFn
  })

  const prefetchSegment = useCallback(
    () =>
      queryClient.prefetchQuery({
        queryKey,
        queryFn: getSegmentFn,
        staleTime: 120_000
      }),
    [queryClient, getSegmentFn, queryKey]
  )

  const fetchSegment = useCallback(
    () =>
      queryClient.fetchQuery({
        queryKey,
        queryFn: getSegmentFn
      }),
    [queryClient, getSegmentFn, queryKey]
  )

  return { prefetchSegment, data: getSegment.data, fetchSegment }
}

const SegmentLink = ({
  id,
  name,
  // type,
  // owner_id,
  appliedSegmentIds,
  closeList
}: SavedSegment & { appliedSegmentIds: number[]; closeList: () => void }) => {
  const { query } = useQueryContext()

  const { prefetchSegment } = useSegmentPrefetch({ id: String(id) })

  return (
    <AppNavigationLink
      className={linkClassName}
      key={id}
      // active={appliedSegmentIds.includes(id)}
      onMouseEnter={prefetchSegment}
      onClick={closeList}
      search={(search) => {
        const otherFilters = query.filters.filter((f) => !isSegmentFilter(f))
        const updatedSegmentIds = appliedSegmentIds.includes(id) ? [] : [id]
        if (!updatedSegmentIds.length) {
          return {
            ...search,
            filters: otherFilters,
            labels: cleanLabels(otherFilters, query.labels)
          }
        }

        const updatedFilters = [
          ['is', 'segment', updatedSegmentIds],
          ...otherFilters
        ]

        return {
          ...search,
          filters: updatedFilters,
          labels: cleanLabels(updatedFilters, query.labels, 'segment', {
            [formatSegmentIdAsLabelKey(id)]: name
          })
        }
      }}
    >
      <div className="truncate">{name}</div>
    </AppNavigationLink>
  )
}
