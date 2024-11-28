/** @format */

import React, { ReactNode, useCallback, useMemo, useState } from 'react'
import {
  DropdownLinkGroup,
  DropdownNavigationLink,
  DropdownSubtitle
} from '../components/dropdown'
import { useQueryContext } from '../query-context'
import { useSiteContext } from '../site-context'
import {
  formatSegmentIdAsLabelKey,
  getFilterSegmentsByNameInsensitive,
  isSegmentFilter,
  parseApiSegmentData,
  SavedSegment,
  SegmentData
} from './segments'
import { QueryFunction, useQuery, useQueryClient } from '@tanstack/react-query'
import { cleanLabels } from '../util/filters'
import {
  AppNavigationLink,
  useAppNavigate
} from '../navigation/use-app-navigate'
import classNames from 'classnames'
import { Tooltip } from '../util/tooltip'
import { useUserContext } from '../user-context'
import { ChevronLeftIcon, ChevronRightIcon } from '@heroicons/react/24/solid'
import { editSegmentRoute, filterRoute, rootRoute } from '../router'
import { SearchInput } from '../components/search-input'
import { SegmentAuthorship } from './segment-authorship'

export const useSegmentsListQuery = () => {
  const site = useSiteContext()
  const { query } = useQueryContext()
  const segmentsFilter = query.filters.find(isSegmentFilter)
  const appliedSegmentIds = segmentsFilter
    ? (segmentsFilter[2] as number[])
    : []
  return useQuery({
    queryKey: ['segments'],
    placeholderData: (previousData) => previousData,
    queryFn: async () => {
      const response = await fetch(
        `/internal-api/${encodeURIComponent(site.domain)}/segments`,
        {
          method: 'GET',
          headers: {
            'content-type': 'application/json',
            accept: 'application/json'
          }
        }
      ).then((res): Promise<SavedSegment[]> => res.json())

      return response.sort(
        (a, b) =>
          appliedSegmentIds.findIndex((id) => id === b.id) -
          appliedSegmentIds.findIndex((id) => id === a.id)
      )
    }
  })
}

const linkClass = 'text-xs'

export const SegmentActionsList = ({
  segment,
  closeList,
  // cancelEditing,
  openUpdateModal,
  openSaveAsNewModal,
  openDeleteModal
}: {
  segment: Pick<SavedSegment, 'name' | 'id'>
  closeList: () => void
  // cancelEditing: () => void
  openUpdateModal: () => void
  openSaveAsNewModal: () => void
  openDeleteModal: () => void
}) => {
  return (
    <>
      <AppNavigationLink
        className="flex text-xs px-4 py-2 gap-1 bg-gray-50 dark:bg-gray-900 rounded-t-md"
        path={rootRoute.path}
        search={(s) => ({ ...s, filters: null, labels: null })}
        onClick={closeList}
      >
        <ChevronLeftIcon className="block h-4 w-4"></ChevronLeftIcon>
        <div>Cancel editing</div>
      </AppNavigationLink>
      <DropdownLinkGroup>
        <DropdownSubtitle className="break-all">
          {segment.name}
        </DropdownSubtitle>
        <DropdownNavigationLink
          className={classNames(linkClass)}
          onClick={openUpdateModal}
          search={(s) => s}
        >
          Update segment
        </DropdownNavigationLink>
        <DropdownNavigationLink
          className={classNames(linkClass)}
          onClick={openSaveAsNewModal}
          search={(s) => s}
        >
          Save as a new segment
        </DropdownNavigationLink>
        <DropdownNavigationLink
          className={classNames(linkClass)}
          onClick={openDeleteModal}
          search={(s) => s}
        >
          Delete segment
        </DropdownNavigationLink>
      </DropdownLinkGroup>
    </>
  )
}

export const SegmentsList = ({
  closeList,
  openSaveModal
}: {
  closeList: () => void
  openSaveModal: () => void
}) => {
  const { query } = useQueryContext()

  const { data } = useSegmentsListQuery()

  const segmentFilter = query.filters.find(isSegmentFilter)
  const appliedSegmentIds = (segmentFilter ? segmentFilter[2] : []) as number[]

  const [search, setSearch] = useState<string>()

  const filteredData = data?.filter(getFilterSegmentsByNameInsensitive(search))

  return (
    <>
      {!!data?.length && (
        <DropdownLinkGroup>
          <DropdownSubtitle>Segments</DropdownSubtitle>

          <div className="px-4 py-1">
            <SearchInput
              placeholderUnfocused="Press / to search segments"
              className="w-full text-xs sm:text-xs"
              onSearch={setSearch}
            />
          </div>
          {filteredData?.slice(0, 5).map((s) => (
            <Tooltip
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
                closeList={closeList}
                {...s}
                appliedSegmentIds={appliedSegmentIds}
              />
            </Tooltip>
          ))}
          {!!data?.length && (
            <DropdownNavigationLink
              className={classNames(linkClass, primaryHoverClass)}
              path={filterRoute.path}
              params={{ field: 'segments' }}
              search={(s) => s}
              onLinkClick={closeList}
            >
              View all
              <ChevronRightIcon className="block w-4 h-4" />
            </DropdownNavigationLink>
          )}
        </DropdownLinkGroup>
      )}
      <DropdownLinkGroup>
        <SaveSelectionAsSegment openSaveModal={openSaveModal} />
      </DropdownLinkGroup>
    </>
  )
}

const primaryHoverClass =
  'font-bold hover:text-indigo-700 dark:hover:text-indigo-500'

const SaveSelectionAsSegment = ({
  openSaveModal
}: {
  openSaveModal: () => void
}) => {
  const { query } = useQueryContext()
  const disabledReason = !query.filters.length
    ? 'Add filters to the dashboard to save a segment.'
    : query.filters.some(isSegmentFilter)
      ? 'Remove the segment filter to save a segment. Segments can not contain other segments.'
      : null
  if (disabledReason === null) {
    return (
      <DropdownNavigationLink
        className={classNames(linkClass, primaryHoverClass)}
        onClick={openSaveModal}
        search={(s) => s}
      >
        Save as segment
      </DropdownNavigationLink>
    )
  }

  return (
    <Tooltip info={<div className="max-w-60">{disabledReason}</div>}>
      <DropdownNavigationLink
        className={classNames(linkClass, 'font-bold')}
        search={(s) => s}
        aria-disabled={true}
      >
        Save as segment
      </DropdownNavigationLink>
    </Tooltip>
  )
}

export const useGetSegmentById = (id?: number) => {
  const site = useSiteContext()
  const queryClient = useQueryClient()
  const queryKey = useMemo(() => ['segments', id] as const, [id])
  const navigate = useAppNavigate()

  const getSegmentFn: QueryFunction<
    SavedSegment & { segment_data: SegmentData },
    typeof queryKey
  > = useCallback(
    async ({ queryKey: [_, id] }) => {
      const res = await fetch(
        `/internal-api/${encodeURIComponent(site.domain)}/segments/${id}`,
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

  const expandSegment = useCallback(
    (segment: SavedSegment & { segment_data: SegmentData }) => {
      try {
        navigate({
          path: `/${editSegmentRoute.path}`,
          params: { id: String(segment.id) },
          search: (search) => ({
            ...search,
            filters: segment.segment_data.filters,
            labels: segment.segment_data.labels
          })
        })
      } catch (_error) {
        return
      }
    },
    [navigate]
  )

  return { prefetchSegment, data: getSegment.data, fetchSegment, expandSegment }
}

const SegmentLink = ({
  id,
  name,
  appliedSegmentIds,
  closeList
}: SavedSegment & { appliedSegmentIds: number[]; closeList: () => void }) => {
  const user = useUserContext()
  const canSeeActions = user.loggedIn
  const { query } = useQueryContext()
  const { prefetchSegment, data, fetchSegment } = useGetSegmentById(id)
  const navigate = useAppNavigate()

  return (
    <DropdownNavigationLink
      className={linkClass}
      key={id}
      active={appliedSegmentIds.includes(id)}
      onMouseEnter={prefetchSegment}
      search={(search) => {
        const otherFilters = query.filters.filter((f) => !isSegmentFilter(f))
        const updatedSegmentIds = [id]

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
      onLinkClick={closeList}
      actions={
        !canSeeActions ? null : (
          <>
            <button
              title="Edit segment"
              className={classNames(iconButtonClass, 'ml-2 shrink-0')}
              onClick={async () => {
                try {
                  const d = data ?? (await fetchSegment())
                  navigate({
                    path: editSegmentRoute.path,
                    params: { id: String(id) },
                    search: (s) => ({
                      ...s,
                      filters: d.segment_data.filters,
                      labels: d.segment_data.labels
                    })
                  })
                } catch (_e: unknown) {
                  navigate({
                    path: editSegmentRoute.path,
                    params: { id: String(id) },
                    search: (s) => ({
                      ...s,
                      filters: [],
                      labels: []
                    })
                  })
                }
              }}
            >
              <EditSegmentIcon className="block w-4 h-4" />
            </button>
          </>
        )
      }
    >
      <div className="truncate">{name}</div>
    </DropdownNavigationLink>
  )
}

export const iconButtonClass =
  'flex items-center justify-center w-5 h-5 fill-current hover:fill-indigo-600'

export const EditSegment = ({
  children,
  className,
  onClick,
  onMouseEnter
}: {
  children?: ReactNode
  onClick: () => Promise<void>
  onMouseEnter?: () => Promise<void>
  className?: string
}) => {
  return (
    <button
      className={classNames(
        'flex items-center justify-center w-5 h-5 fill-current hover:fill-indigo-600',
        className
      )}
      onClick={onClick}
      onMouseEnter={onMouseEnter}
    >
      {children}
      <EditSegmentIcon className="block w-4 h-4" />
    </button>
  )
}

export const EditSegmentIcon = ({ className }: { className?: string }) => (
  <svg
    className={className}
    viewBox="0 0 16 16"
    xmlns="http://www.w3.org/2000/svg"
  >
    <path d="M14.2075 4.58572L11.4144 1.79322C11.3215 1.70034 11.2113 1.62666 11.0899 1.57639C10.9686 1.52612 10.8385 1.50024 10.7072 1.50024C10.5759 1.50024 10.4458 1.52612 10.3245 1.57639C10.2031 1.62666 10.0929 1.70034 10 1.79322L2.29313 9.50009C2.19987 9.59262 2.12593 9.70275 2.0756 9.82411C2.02528 9.94546 1.99959 10.0756 2.00001 10.207V13.0001C2.00001 13.2653 2.10536 13.5197 2.2929 13.7072C2.48043 13.8947 2.73479 14.0001 3 14.0001H13.5C13.6326 14.0001 13.7598 13.9474 13.8536 13.8536C13.9473 13.7599 14 13.6327 14 13.5001C14 13.3675 13.9473 13.2403 13.8536 13.1465C13.7598 13.0528 13.6326 13.0001 13.5 13.0001H7.2075L14.2075 6.00009C14.3004 5.90723 14.3741 5.79698 14.4243 5.67564C14.4746 5.5543 14.5005 5.42425 14.5005 5.29291C14.5005 5.16156 14.4746 5.03151 14.4243 4.91017C14.3741 4.78883 14.3004 4.67858 14.2075 4.58572ZM5.79313 13.0001H3V10.207L8.5 4.70697L11.2931 7.50009L5.79313 13.0001ZM12 6.79322L9.20751 4.00009L10.7075 2.50009L13.5 5.29322L12 6.79322Z" />
  </svg>
)
