/** @format */

import React, { ReactNode, useCallback, useMemo, useRef, useState } from 'react'
import {
  DropdownLinkGroup,
  DropdownMenuWrapper,
  DropdownNavigationLink,
  DropdownSubtitle,
  ToggleDropdownButton
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
import { useAppNavigate } from '../navigation/use-app-navigate'
import classNames from 'classnames'
import { Tooltip } from '../util/tooltip'
import { useUserContext } from '../user-context'
import {
  SegmentExpandedLocationState,
  useSegmentExpandedContext
} from './segment-expanded-context'
import { filterRoute, rootRoute } from '../router'
import { SegmentAuthorship } from './segment-authorship'
import {
  CheckIcon,
  PencilSquareIcon,
  Square2StackIcon,
  TrashIcon,
  XMarkIcon,
  ChevronRightIcon
} from '@heroicons/react/24/outline'
import { useOnClickOutside } from '../util/use-on-click-outside'

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

export const SegmentsList = ({
  closeList,
  searchValue
}: {
  closeList: () => void
  searchValue?: string
}) => {
  const { query } = useQueryContext()

  const { data } = useSegmentsListQuery()

  const segmentFilter = query.filters.find(isSegmentFilter)
  const appliedSegmentIds = (segmentFilter ? segmentFilter[2] : []) as number[]
  const filteredData = data?.filter(
    getFilterSegmentsByNameInsensitive(searchValue)
  )
  const showableSlice = filteredData?.slice(0, 5)

  return (
    <>
      {!!data?.length && (
        <DropdownLinkGroup>
          {/* <> */}
          <DropdownSubtitle>Segments</DropdownSubtitle>

          {showableSlice!.map((s) => {
            return (
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
                  {...s}
                  appliedSegmentIds={appliedSegmentIds}
                  closeList={closeList}
                />
              </Tooltip>
            )
          })}
          {!!data?.length && (
            <DropdownNavigationLink
              className={classNames(
                linkClass,
                'font-bold hover:text-indigo-700 dark:hover:text-indigo-500'
              )}
              path={filterRoute.path}
              params={{ field: 'segment' }}
              search={(s) => s}
              onLinkClick={closeList}
            >
              View all
              <ChevronRightIcon className="block w-4 h-4" />
            </DropdownNavigationLink>
          )}
        </DropdownLinkGroup>
      )}
      {/* <DropdownLinkGroup> */}
      {/* <SaveSelectionAsSegment closeList={closeList} /> */}
      {/* <DropdownNavigationLink
          className={classNames(linkClass, 'font-bold')}
          search={(s) => s}
          navigateOptions={{
            state: {
              modal: 'create',
              expandedSegment: null
            } as SegmentExpandedLocationState
          }}
          onLinkClick={closeList}
          {...((query.filters.some(isSegmentFilter) ||
            !query.filters.length) && {
            'aria-disabled': true,
            navigateOptions: undefined,
            onLinkClick: undefined
          })}
        >
          Save selection as segment
        </DropdownNavigationLink> */}
      {/* </DropdownLinkGroup> */}
    </>
  )
}

export const SaveSelectionAsSegment = ({
  closeList
}: {
  closeList: () => void
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
        className={classNames(
          linkClass,
          'font-bold hover:text-indigo-700 dark:hover:text-indigo-500'
        )}
        search={(s) => s}
        navigateOptions={{
          state: {
            modal: 'create',
            expandedSegment: null
          } as SegmentExpandedLocationState
        }}
        onLinkClick={closeList}
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

export const useSegmentPrefetch = ({ id }: Pick<SavedSegment, 'id'>) => {
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
          path: rootRoute.path,
          search: (search) => ({
            ...search,
            filters: segment.segment_data.filters,
            labels: segment.segment_data.labels
          }),
          state: {
            expandedSegment: {
              id: segment.id,
              name: segment.name,
              type: segment.type,
              owner_id: segment.owner_id
            }
          } as SegmentExpandedLocationState
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
  // type,
  // owner_id,
  appliedSegmentIds,
  closeList
}: SavedSegment & { appliedSegmentIds: number[]; closeList: () => void }) => {
  const user = useUserContext()
  const canSeeActions = user.loggedIn
  // const canDeleteSegment =
  //   user.loggedIn &&
  //   ((owner_id === user.id && type === SegmentType.personal) ||
  //     (type === SegmentType.site &&
  //       ['admin', 'owner', 'super_admin'].includes(user.role)))
  const { query } = useQueryContext()
  const { prefetchSegment, expandSegment, data, fetchSegment } =
    useSegmentPrefetch({ id })

  return (
    <DropdownNavigationLink
      className={linkClass}
      key={id}
      active={appliedSegmentIds.includes(id)}
      onMouseEnter={prefetchSegment}
      navigateOptions={{
        state: { expandedSegment: null } as SegmentExpandedLocationState
      }}
      onLinkClick={closeList}
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
      actions={
        !canSeeActions ? null : (
          <>
            <button
              title="Edit segment"
              className={classNames(iconButtonClass, 'ml-2 shrink-0')}
              onClick={async () => {
                expandSegment(data ?? (await fetchSegment()))
                closeList()
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

export const EditSegmentMenu = () => {
  const dropdownRef = useRef<HTMLDivElement>(null)
  const { expandedSegment, modal } = useSegmentExpandedContext()
  const [opened, setOpened] = useState(false)
  useOnClickOutside({
    ref: dropdownRef,
    active: opened && modal === null,
    handler: () => setOpened(false)
  })
  if (!expandedSegment) {
    return null
  }
  return (
    <ToggleDropdownButton
      ref={dropdownRef}
      variant="ghost"
      className="ml-auto md:relative shrink-0"
      dropdownContainerProps={{
        ['aria-controls']: 'edit-segment-menu',
        ['aria-expanded']: opened
      }}
      onClick={() => setOpened((v) => !v)}
      currentOption={
        <div>
          <EditSegmentIcon className="w-4 h-4 block fill-current"/>
        </div>
      }
    >
      {opened && (
        <DropdownMenuWrapper
          id="edit-segment-menu"
          className="md:left-auto md:w-60"
        >
          <DropdownLinkGroup>
            <DropdownSubtitle className="break-all normal-case">
              {expandedSegment.name}
            </DropdownSubtitle>

            <DropdownNavigationLink
              className={linkClass}
              search={(s) => s}
              navigateOptions={{
                state: {
                  expandedSegment: expandedSegment,
                  modal: 'update'
                } as SegmentExpandedLocationState
              }}
              onLinkClick={() => setOpened(false)}
            >
              <div className="flex items-center gap-x-2">
                <CheckIcon className="w-4 h-4 block" />
                Update segment
              </div>
            </DropdownNavigationLink>
            <DropdownNavigationLink
              className={linkClass}
              search={(s) => s}
              navigateOptions={{
                state: {
                  expandedSegment: expandedSegment,
                  modal: 'create'
                } as SegmentExpandedLocationState
              }}
              onClick={() => setOpened(false)}
            >
              <div className="flex items-center gap-x-2">
                <Square2StackIcon className="w-4 h-4 block" />
                Save as a new segment
              </div>
            </DropdownNavigationLink>

            <DropdownNavigationLink
              className={linkClass}
              search={(s) => s}
              navigateOptions={{
                state: {
                  expandedSegment: expandedSegment,
                  modal: 'delete'
                } as SegmentExpandedLocationState
              }}
              onLinkClick={() => setOpened(false)}
              // onClick={closeList}
            >
              <div className="flex items-center gap-x-2">
                <TrashIcon className="w-4 h-4 block" />
                Delete segment
              </div>
            </DropdownNavigationLink>
            <DropdownNavigationLink
              className={linkClass}
              search={(s) => ({
                ...s,
                filters: [['is', 'segment', [expandedSegment.id]]],
                labels: {
                  [formatSegmentIdAsLabelKey(expandedSegment.id)]:
                    expandedSegment.name
                }
              })}
              navigateOptions={{
                state: {
                  expandedSegment: null,
                  modal: null
                } as SegmentExpandedLocationState
              }}
              onLinkClick={() => setOpened(false)}
            >
              <div className="flex items-center gap-x-2">
                <XMarkIcon className="w-4 h-4 block" />
                Close without saving
              </div>
            </DropdownNavigationLink>
          </DropdownLinkGroup>
        </DropdownMenuWrapper>
      )}
    </ToggleDropdownButton>
  )
}
