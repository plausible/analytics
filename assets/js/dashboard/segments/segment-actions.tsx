/** @format */

import React, { useState, useCallback } from 'react'
import { useAppNavigate } from '../navigation/use-app-navigate'
import { useQueryContext } from '../query-context'
import { useMutation } from '@tanstack/react-query'
import { DashboardQuery } from '../query'
import { useSiteContext } from '../site-context'
import {
  cleanLabels,
  plainFilterText,
  remapToApiFilters
} from '../util/filters'
import { formatSegmentIdAsLabelKey } from './segments'
import { CreateSegmentModal } from './segment-modals'

export const SaveSegmentAction = () => {
  const site = useSiteContext()
  const { query } = useQueryContext()
  const [modal, setModal] = useState<null | 'create segment'>(null)
  const navigate = useAppNavigate()
  const openCreateSegment = useCallback(() => {
    return setModal('create segment')
  }, [])
  const close = useCallback(() => {
    return setModal(null)
  }, [])

  const createSegment = useMutation({
    mutationFn: ({
      name,
      personal,
      segment_data
    }: {
      name: string
      personal: boolean
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
            personal,
            segment_data: {
              filters: remapToApiFilters(segment_data.filters),
              labels: cleanLabels(segment_data.filters, segment_data.labels)
            }
          }),
          headers: { 'content-type': 'application/json' }
        }
      ).then((res) => res.json())
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
        }
      })
      close()
    }
  })

  const segmentNamePlaceholder = query.filters.reduce(
    (combinedName, filter) =>
      combinedName.length > 100
        ? combinedName
        : `${combinedName}${combinedName.length ? ' and ' : ''}${plainFilterText(query, filter)}`,
    ''
  )

  return (
    <div>
      <button
        className="whitespace-nowrap rounded font-medium text-sm leading-tight px-2 py-2 h-9 hover:text-indigo-700 dark:hover:text-indigo-500"
        onClick={openCreateSegment}
      >
        Save segment
      </button>
      {modal === 'create segment' && (
        <CreateSegmentModal
          namePlaceholder={segmentNamePlaceholder}
          close={close}
          onSave={({ name, personal }) =>
            createSegment.mutate({
              name,
              personal,
              segment_data: {
                filters: query.filters,
                labels: query.labels
              }
            })
          }
        />
      )}
    </div>
  )
}
