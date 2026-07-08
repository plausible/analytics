import React from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useSiteContext } from '../site-context'
import { useUserContext } from '../user-context'
import { get, mutation } from '../api'
import { useRoutelessModalsContext } from '../navigation/routeless-modals-context'
import {
  CreateAnnotationModal,
  DeleteAnnotationModal,
  UpdateAnnotationModal
} from './annotations-modals'
import {
  Annotation,
  AnnotationPayload,
  getApiFormattedPayload
} from './annotations'
import { useDashboardStateContext } from '../dashboard-state-context'
import { createDateRange } from '../stats-query'
import { formatISO } from '../util/date'
import { DashboardState } from '../dashboard-state'

export const useGetAnnotations = () => {
  const site = useSiteContext()
  const { dashboardState } = useDashboardStateContext()
  const date_range = createDateRange(dashboardState)
  const relative_date = dashboardState.date
    ? formatISO(dashboardState.date)
    : null

  const dateRangeParams: Record<string, string> = Array.isArray(date_range)
    ? { date_range_start: date_range[0], date_range_end: date_range[1] }
    : { date_range }

  const annotationsIndexQuery = useQuery({
    queryKey: ['annotations', { date_range, relative_date }],
    queryFn: async () => {
      const response: Annotation[] = await get(
        `/api/${encodeURIComponent(site.domain)}/annotations`,
        // workaround to allow custom params to be defined
        // without passing the whole dashboard state
        {} as unknown as DashboardState,
        {
          ...dateRangeParams,
          ...(relative_date ? { relative_date } : {})
        }
      )
      return response
    }
  })
  return annotationsIndexQuery
}

export type RoutelessAnnotationModal =
  | { type: 'create-annotation'; annotation: AnnotationPayload }
  | { type: 'update-annotation'; annotation: Annotation }
  | { type: 'delete-annotation'; annotation: Annotation }

export const RoutelessAnnotationModals = () => {
  const queryClient = useQueryClient()
  const site = useSiteContext()
  const { modal, setModal } = useRoutelessModalsContext()
  const user = useUserContext()

  const patchAnnotation = useMutation({
    mutationFn: async ({
      id,
      note,
      type
    }: Pick<Annotation, 'id'> & Partial<Pick<Annotation, 'note' | 'type'>>) => {
      const response: Annotation = await mutation(
        `/api/${encodeURIComponent(site.domain)}/annotations/${id}`,
        {
          method: 'PATCH',
          body: {
            note,
            type
          }
        }
      )

      return response
    },
    onSuccess: async () => {
      queryClient.invalidateQueries({ queryKey: ['annotations'] })
      setModal(null)
    }
  })

  const createAnnotation = useMutation({
    mutationFn: async (payload: AnnotationPayload) => {
      const response: Annotation = await mutation(
        `/api/${encodeURIComponent(site.domain)}/annotations`,
        {
          method: 'POST',
          body: getApiFormattedPayload(payload)
        }
      )
      return response
    },
    onSuccess: async () => {
      queryClient.invalidateQueries({ queryKey: ['annotations'] })
      setModal(null)
    }
  })

  const deleteAnnotation = useMutation({
    mutationFn: async (data: Pick<Annotation, 'id'>) => {
      const response: Annotation = await mutation(
        `/api/${encodeURIComponent(site.domain)}/annotations/${data.id}`,
        {
          method: 'DELETE'
        }
      )
      return response
    },
    onSuccess: (): void => {
      queryClient.invalidateQueries({ queryKey: ['annotations'] })
      setModal(null)
    }
  })

  if (!user.loggedIn) {
    return null
  }

  return (
    <>
      {modal?.type === 'delete-annotation' && (
        <DeleteAnnotationModal
          annotation={modal.annotation}
          onClose={() => {
            setModal(null)
            deleteAnnotation.reset()
          }}
          onSave={({ id }) => deleteAnnotation.mutate({ id })}
          status={deleteAnnotation.status}
          error={deleteAnnotation.error}
          reset={deleteAnnotation.reset}
        />
      )}

      {modal?.type === 'update-annotation' && (
        <UpdateAnnotationModal
          user={user}
          siteAnnotationsAvailable={site.siteAnnotationsAvailable}
          annotation={modal.annotation}
          notePlaceholder={''}
          onClose={() => {
            setModal(null)
            patchAnnotation.reset()
          }}
          onSave={({ id, note, type }) =>
            patchAnnotation.mutate({
              id,
              note,
              type
            })
          }
          onDelete={(annotation) =>
            setModal({ type: 'delete-annotation', annotation })
          }
          status={patchAnnotation.status}
          error={patchAnnotation.error}
          reset={patchAnnotation.reset}
        />
      )}
      {modal?.type === 'create-annotation' && (
        <CreateAnnotationModal
          user={user}
          siteAnnotationsAvailable={site.siteAnnotationsAvailable}
          notePlaceholder={modal.annotation.note}
          initialType={modal.annotation.type}
          initialDatetime={modal.annotation.datetime}
          initialGranularity={modal.annotation.granularity}
          onClose={() => {
            setModal(null)
            createAnnotation.reset()
          }}
          onSave={(payload) => createAnnotation.mutate(payload)}
          status={createAnnotation.status}
          error={createAnnotation.error}
          reset={createAnnotation.reset}
        />
      )}
    </>
  )
}
