/** @format */

import React from 'react'
import { useQueryContext } from '../query-context'
import { FilterPill } from './filter-pill'
import {
  cleanLabels,
  EVENT_PROPS_PREFIX,
  FILTER_GROUP_TO_MODAL_TYPE,
  plainFilterText,
  remapToApiFilters,
  styledFilterText
} from '../util/filters'
import {
  AppNavigationLink,
  useAppNavigate
} from '../navigation/use-app-navigate'
import { XMarkIcon } from '@heroicons/react/20/solid'
import { useMutation } from '@tanstack/react-query'
import { useSiteContext } from '../site-context'
import { DashboardQuery } from '../query'

export function FilterPillsList() {
  const site = useSiteContext()
  const { query } = useQueryContext()
  const navigate = useAppNavigate()

  const saveAs = useMutation({
    mutationFn: (data: {
      name: string
      personal: boolean
      segment_data: { filters: DashboardQuery['filters'] }
    }) => {
      return fetch(
        `/internal-api/${encodeURIComponent(site.domain)}/segments`,
        {
          method: 'POST',
          body: JSON.stringify(data),
          headers: { 'content-type': 'application/json' }
        }
      ).then((res) => res.json())
    },
    onSuccess: async (d) => {
      navigate({
        search: (search) => ({
          ...search,
          filters: [['is', 'segment', [d.id]]],
          labels: { [d.id]: [d.name] }
        })
      })
    }
  })
  const save = useMutation({
    mutationFn: ({
      id,
      ...data
    }: {
      id: number
      name?: string
      personal?: boolean
      segment_data: { filters: DashboardQuery['filters'] }
    }) => {
      return fetch(
        `/internal-api/${encodeURIComponent(site.domain)}/segments/${id}`,
        {
          method: 'PATCH',
          body: JSON.stringify(data),
          headers: { 'content-type': 'application/json' }
        }
      )
    },
    onSuccess: (_d, _id) => {
      navigate({
        search: (search) => ({
          ...search,
          filters: query.filters.filter((f) => f[1] === 'segment')
        })
      })
    }
  })

  const segmentInFilters = query.filters.find((f) => f[1] === 'segment')

  return (
    <div className="flex items-center">
      <div
        id="filters"
        className="flex flex-wrap rounded border-2 border-transparent"
      >
        {query.filters.map((filter, index) => (
          <FilterPill
            modalToOpen={
              FILTER_GROUP_TO_MODAL_TYPE[
                filter[1].startsWith(EVENT_PROPS_PREFIX) ? 'props' : filter[1]
              ]
            }
            plainText={plainFilterText(query, filter)}
            key={index}
            onRemoveClick={() =>
              navigate({
                search: (search) => ({
                  ...search,
                  filters: query.filters.filter((_, i) => i !== index),
                  labels: cleanLabels(query.filters, query.labels)
                })
              })
            }
          >
            {styledFilterText(query, filter)}
          </FilterPill>
        ))}
      </div>
      {!!query.filters.length && (
        <>
          <AppNavigationLink
            className=""
            search={(search) => ({
              ...search,
              filters: null,
              labels: null
            })}
          >
            <XMarkIcon className="w-4 h-4" />
          </AppNavigationLink>
          <div className="px-4">{'|'}</div>
          {!segmentInFilters && (
            <button
              disabled={saveAs.isPending}
              onClick={() =>
                saveAs.mutate({
                  name: String(Math.random() * 10000),
                  personal: true,
                  segment_data: { filters: remapToApiFilters(query.filters) }
                })
              }
            >
              {saveAs.isPending ? 'Saving...' : 'Save as'}
            </button>
          )}
          {segmentInFilters && (
            <button
              disabled={save.isPending}
              onClick={() =>
                save.mutate({
                  id: segmentInFilters[2][0] as number,
                  segment_data: {
                    filters: remapToApiFilters(
                      query.filters.filter((f) => f[1] !== 'segment')
                    )
                  }
                })
              }
            >
              {save.isPending ? 'Saving...' : 'Save'}
            </button>
          )}
        </>
      )}
    </div>
  )
}
