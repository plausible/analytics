/** @format */

import React, { ReactNode, useCallback, useMemo, useRef, useState } from 'react'
import {
  DropdownLinkGroup,
  DropdownMenuWrapper,
  DropdownNavigationLink,
  DropdownSubtitle,
  SplitButton
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
} from '../filtering/segments'
import { QueryFunction, useQuery, useQueryClient } from '@tanstack/react-query'
import { cleanLabels } from '../util/filters'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import classNames from 'classnames'
import { Tooltip } from '../util/tooltip'
import { useSegmentExpandedContext } from './segment-expanded-context'
import { SegmentAuthorship } from './segment-authorship'
import {
  CheckIcon,
  Square2StackIcon,
  TrashIcon,
  XMarkIcon
} from '@heroicons/react/24/outline'
import { useOnClickOutside } from '../util/use-on-click-outside'
import { isModifierPressed, isTyping, Keybind } from '../keybinding'
import { primaryNeutralButtonClass } from './segment-modals'
import { SearchInput } from '../components/search-input'
import { EllipsisHorizontalIcon } from '@heroicons/react/24/solid'

export const useSegmentsListQuery = () => {
  const site = useSiteContext()
  const appliedSegmentIds = [] as number[]
  return useQuery({
    queryKey: ['segments'],
    placeholderData: (previousData) => previousData,
    queryFn: async () => {
      const response = await fetch(
        `/api/${encodeURIComponent(site.domain)}/segments`,
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
  closeList
  // searchValue
}: {
  closeList: () => void
  // searchValue?: string
}) => {
  const { query } = useQueryContext()

  const { data } = useSegmentsListQuery()
  const [searchValue, setSearch] = useState<string>()
  const initialSliceLength = 5
  const [sliceLength, setSliceLength] = useState(initialSliceLength)
  const segmentFilter = query.filters.find(isSegmentFilter)
  const appliedSegmentIds = (segmentFilter ? segmentFilter[2] : []) as number[]
  const filteredData = data?.filter(
    getFilterSegmentsByNameInsensitive(searchValue)
  )
  // const max = 5
  const showableSlice = filteredData?.slice(0, sliceLength)
  const { expandedSegment } = useSegmentExpandedContext()
  if (expandedSegment) {
    return null
  }

  return (
    <>
      {!!data?.length && (
        <DropdownLinkGroup>
          <div className="flex items-center mt-1 ">
            <DropdownSubtitle>Segments</DropdownSubtitle>
            {data.length > initialSliceLength && (
              <SearchInput
                placeholderUnfocused="Press / to search"
                className="w-full text-xs sm:text-xs text-xs py-1 mr-4"
                onSearch={setSearch}
              />
            )}
          </div>

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
          {!!data?.length && sliceLength < data.length && (
            <DropdownNavigationLink
              className={classNames(
                linkClass,
                'font-bold hover:text-indigo-700 dark:hover:text-indigo-500'
              )}
              // path={filterRoute.path}
              // params={{ field: 'segment' }}
              search={(s) => s}
              onClick={() => setSliceLength(data.length)}
            >
              View all
              <EllipsisHorizontalIcon className="block w-4 h-4" />
            </DropdownNavigationLink>
          )}
        </DropdownLinkGroup>
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
    <DropdownNavigationLink
      className={linkClass}
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
    <SplitButton
      ref={dropdownRef}
      className="ml-auto md:relative shrink-0"
      dropdownContainerProps={{
        ['aria-controls']: 'edit-segment-menu',
        ['aria-expanded']: opened
      }}
      onClick={() => setOpened((v) => !v)}
      leftOption={
        <AppNavigationLink
          className={classNames(
            primaryNeutralButtonClass,
            '!px-2 !py-2',
            'rounded-r-none'
          )}
          search={(s) => s}
          state={{ expandedSegment, modal: 'update' }}
          onClick={() => setOpened(false)}
        >
          Update segment
        </AppNavigationLink>
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
              navigateOptions={{ state: { expandedSegment, modal: 'update' } }}
              onClick={() => {
                setOpened(false)
              }}
            >
              <div className="flex items-center gap-x-2">
                <CheckIcon className="w-4 h-4 block" />
                Update segment
              </div>
            </DropdownNavigationLink>
            <DropdownNavigationLink
              className={linkClass}
              search={(s) => s}
              navigateOptions={{ state: { expandedSegment, modal: 'create' } }}
              onClick={() => {
                setOpened(false)
              }}
            >
              <div className="flex items-center gap-x-2">
                <Square2StackIcon className="w-4 h-4 block" />
                Save as a new segment
              </div>
            </DropdownNavigationLink>

            <DropdownNavigationLink
              className={linkClass}
              search={(s) => s}
              navigateOptions={{ state: { expandedSegment, modal: 'delete' } }}
              onClick={() => {
                setOpened(false)
              }}
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
                filters: [],
                labels: {}
                // filters: [[['is', 'segment', [expandedSegment.id]]]],
                // labels: {
                //   [formatSegmentIdAsLabelKey(expandedSegment.id)]:
                //     expandedSegment.name
                // }
              })}
              navigateOptions={{
                state: { expandedSegment: null, modal: null }
              }}
              onClick={() => {
                setOpened(false)
              }}
            >
              <div className="flex items-center gap-x-2">
                <XMarkIcon className="w-4 h-4 block" />
                Close without saving
              </div>
            </DropdownNavigationLink>
          </DropdownLinkGroup>
          <Keybind
            keyboardKey="Escape"
            shouldIgnoreWhen={[isModifierPressed, isTyping]}
            type="keyup"
            handler={(event) => {
              event.stopPropagation()
              setOpened(false)
            }}
            target={dropdownRef.current}
          />
        </DropdownMenuWrapper>
      )}
    </SplitButton>
  )
}
