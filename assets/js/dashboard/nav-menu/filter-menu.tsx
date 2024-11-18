/** @format */

import React, { useMemo, useRef, useState } from 'react'
import {
  DropdownLinkGroup,
  DropdownMenuWrapper,
  DropdownNavigationLink,
  ToggleDropdownButton
} from '../components/dropdown'
import { MagnifyingGlassIcon } from '@heroicons/react/20/solid'
import {
  cleanLabels,
  FILTER_MODAL_TO_FILTER_GROUP,
  formatFilterGroup,
  remapToApiFilters
} from '../util/filters'
import { PlausibleSite, useSiteContext } from '../site-context'
import { filterRoute } from '../router'
import { useOnClickOutside } from '../util/use-on-click-outside'
import { SegmentsList } from '../segments/segments-dropdown'
import { useQueryContext } from '../query-context'
import {
  SegmentExpandedLocationState,
  useSegmentExpandedContext
} from '../segments/segment-expanded-context'
import {
  CreateSegmentModal,
  DeleteSegmentModal,
  UpdateSegmentModal
} from '../segments/segment-modals'
import { useUserContext } from '../user-context'
import {
  formatSegmentIdAsLabelKey,
  getSegmentNamePlaceholder,
  isSegmentFilter,
  parseApiSegmentData,
  SavedSegment
} from '../segments/segments'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useAppNavigate } from '../navigation/use-app-navigate'
import { DashboardQuery } from '../query'

export function getFilterListItems({
  propsAvailable
}: Pick<PlausibleSite, 'propsAvailable'>): {
  modalKey: string
  label: string
}[] {
  const allKeys = Object.keys(FILTER_MODAL_TO_FILTER_GROUP) as Array<
    keyof typeof FILTER_MODAL_TO_FILTER_GROUP
  >
  const keysToOmit: Array<keyof typeof FILTER_MODAL_TO_FILTER_GROUP> =
    propsAvailable ? ['segment'] : ['segment', 'props']
  return allKeys
    .filter((k) => !keysToOmit.includes(k))
    .map((modalKey) => ({ modalKey, label: formatFilterGroup(modalKey) }))
}

export const FilterMenu = () => {
  const user = useUserContext()
  const dropdownRef = useRef<HTMLDivElement>(null)
  const [opened, setOpened] = useState(false)
  const site = useSiteContext()
  const filterListItems = useMemo(() => getFilterListItems(site), [site])
  const { query } = useQueryContext()
  const { expandedSegment, modal } = useSegmentExpandedContext()
  const queryClient = useQueryClient()
  const navigate = useAppNavigate()
  const patchSegment = useMutation({
    mutationFn: ({
      id,
      name,
      type,
      segment_data
    }: Pick<SavedSegment, 'id'> &
      Partial<Pick<SavedSegment, 'name' | 'type'>> & {
        segment_data?: {
          filters: DashboardQuery['filters']
          labels: DashboardQuery['labels']
        }
      }) => {
      return fetch(
        `/internal-api/${encodeURIComponent(site.domain)}/segments/${id}`,
        {
          method: 'PATCH',
          body: JSON.stringify({
            name,
            type,
            ...(segment_data && {
              segment_data: {
                filters: remapToApiFilters(segment_data.filters),
                labels: cleanLabels(segment_data.filters, segment_data.labels)
              }
            })
          }),
          headers: {
            'content-type': 'application/json',
            accept: 'application/json'
          }
        }
      )
        .then((res) => res.json())
        .then((d) => ({
          ...d,
          segment_data: parseApiSegmentData(d.segment_data)
        }))
    },
    onSuccess: async (d) => {
      navigate({
        search: (search) => {
          const filters = [['is', 'segment', [d.id]]]
          const labels = cleanLabels(filters, {}, 'segment', {
            [formatSegmentIdAsLabelKey(d.id)]: d.name
          })
          return {
            ...search,
            filters,
            labels
          }
        },
        state: {
          expandedSegment: null,
          modal: null
        } as SegmentExpandedLocationState
      })
      queryClient.invalidateQueries({ queryKey: ['segments'] })
    }
  })

  const createSegment = useMutation({
    mutationFn: ({
      name,
      type,
      segment_data
    }: {
      name: string
      type: 'personal' | 'site'
      segment_data: {
        filters: DashboardQuery['filters']
        labels: DashboardQuery['labels']
      }
    }) => {
      return fetch(
        `/internal-api/${encodeURIComponent(site.domain)}/segments`,
        {
          method: 'POST',
          body: JSON.stringify({
            name,
            type,
            segment_data: {
              filters: remapToApiFilters(segment_data.filters),
              labels: cleanLabels(segment_data.filters, segment_data.labels)
            }
          }),
          headers: { 'content-type': 'application/json' }
        }
      )
        .then((res) => res.json())
        .then((d) => ({
          ...d,
          segment_data: parseApiSegmentData(d.segment_data)
        }))
    },
    onSuccess: async (d) => {
      navigate({
        search: (search) => {
          const filters = [['is', 'segment', [d.id]]]
          const labels = cleanLabels(filters, {}, 'segment', {
            [formatSegmentIdAsLabelKey(d.id)]: d.name
          })
          return {
            ...search,
            filters,
            labels
          }
        },
        state: {
          expandedSegment: null,
          modal: null
        } as SegmentExpandedLocationState
      })
      queryClient.invalidateQueries({ queryKey: ['segments'] })
    }
  })
  const deleteSegment = useMutation({
    mutationFn: (data: Pick<SavedSegment, 'id'>) => {
      return fetch(
        `/internal-api/${encodeURIComponent(site.domain)}/segments/${data.id}`,
        {
          method: 'DELETE'
        }
      )
        .then((res) => res.json())
        .then((d) => ({
          ...d,
          segment_data: parseApiSegmentData(d.segment_data)
        }))
    },
    onSuccess: (_d): void => {
      navigate({
        search: (s) => {
          return {
            ...s,
            filters: null,
            labels: null
          }
        },
        state: {
          expandedSegment: null,
          modal: null
        } as SegmentExpandedLocationState
      })
      queryClient.invalidateQueries({ queryKey: ['segments'] })
    }
  })

  useOnClickOutside({
    ref: dropdownRef,
    active: opened && modal === null,
    handler: () => setOpened(false)
  })

  return (
    <>
      {user.loggedIn && modal === 'update' && expandedSegment && (
        <UpdateSegmentModal
          canTogglePersonal={['admin', 'owner', 'super_admin'].includes(
            user.role
          )}
          segment={expandedSegment}
          namePlaceholder={getSegmentNamePlaceholder(query)}
          close={() =>
            navigate({
              search: (s) => s,
              state: { expandedSegment: expandedSegment, modal: null }
            })
          }
          onSave={({ id, name, type }) =>
            patchSegment.mutate({
              id,
              name,
              type,
              segment_data: {
                filters: query.filters,
                labels: query.labels
              }
            })
          }
        />
      )}
      {user.loggedIn && modal === 'create' && (
        <CreateSegmentModal
          canTogglePersonal={['admin', 'owner', 'super_admin'].includes(
            user.role
          )}
          segment={expandedSegment!}
          namePlaceholder={getSegmentNamePlaceholder(query)}
          close={() =>
            navigate({
              search: (s) => s,
              state: { expandedSegment: expandedSegment, modal: null }
            })
          }
          onSave={({ name, type }) =>
            createSegment.mutate({
              name,
              type,
              segment_data: {
                filters: query.filters,
                labels: query.labels
              }
            })
          }
        />
      )}
      {user.loggedIn && modal === 'delete' && expandedSegment && (
        <DeleteSegmentModal
          segment={expandedSegment}
          close={() =>
            navigate({
              search: (s) => s,
              state: { expandedSegment: expandedSegment, modal: null }
            })
          }
          onSave={({ id }) => deleteSegment.mutate({ id })}
        />
      )}

      <ToggleDropdownButton
        ref={dropdownRef}
        variant="ghost"
        className="ml-auto md:relative shrink-0"
        dropdownContainerProps={{
          ['aria-controls']: 'filter-menu',
          ['aria-expanded']: opened
        }}
        onClick={() => setOpened((opened) => !opened)}
        currentOption={
          <span className="flex items-center">
            <MagnifyingGlassIcon className="block h-4 w-4" />
            <span className="block ml-1">Filter</span>
          </span>
        }
      >
        {opened && (
          <DropdownMenuWrapper
            id="filter-menu"
            className="md:left-auto md:w-56"
          >
            <SegmentsList closeList={() => setOpened(false)} />
            <DropdownLinkGroup>
              {filterListItems.map(({ modalKey, label }) => (
                <DropdownNavigationLink
                  onLinkClick={() => setOpened(false)}
                  active={false}
                  key={modalKey}
                  path={filterRoute.path}
                  params={{ field: modalKey }}
                  search={(search) => search}
                >
                  {label}
                </DropdownNavigationLink>
              ))}
            </DropdownLinkGroup>
            {!!query.filters.length && (
              <DropdownLinkGroup>
                <DropdownNavigationLink
                  search={(s) => ({ ...s, filters: null, labels: null })}
                >
                  Clear all filters
                </DropdownNavigationLink>
                {expandedSegment === null && (
                  <DropdownNavigationLink
                  search={(s) => s}
                  navigateOptions={{
                    state: {
                      modal: 'create',
                      expandedSegment: null
                    } as SegmentExpandedLocationState
                  }}
                  {...query.filters.some(isSegmentFilter) && {"aria-disabled": true, navigateOptions: undefined }}
                  >
                    Save as segment
                  </DropdownNavigationLink>
                )}
              </DropdownLinkGroup>
            )}
          </DropdownMenuWrapper>
        )}
      </ToggleDropdownButton>
    </>
  )
}
