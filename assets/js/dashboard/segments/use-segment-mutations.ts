import { useMutation, useQueryClient } from '@tanstack/react-query'
import { mutation } from '../api'
import { showToast } from '../components/toast'
import { useSiteContext } from '../site-context'
import { useAppNavigate } from '../navigation/use-app-navigate'
import { useRoutelessModalsContext } from '../navigation/routeless-modals-context'
import { useSegmentsContext } from '../filtering/segments-context'
import { cleanLabels, remapToApiFilters } from '../util/filters'
import {
  getSearchToSetSegmentFilter,
  handleSegmentResponse,
  SavedSegment,
  SegmentData,
  SegmentDataFromApi
} from '../filtering/segments'

const toApiSegmentData = (segment_data: SegmentData) => ({
  filters: remapToApiFilters(segment_data.filters),
  labels: cleanLabels(segment_data.filters, segment_data.labels)
})

export function useCreateSegment() {
  const { addOne } = useSegmentsContext()
  const navigate = useAppNavigate()
  const queryClient = useQueryClient()
  const site = useSiteContext()
  const { setModal } = useRoutelessModalsContext()

  return useMutation({
    mutationFn: async ({
      name,
      type,
      segment_data
    }: {
      name: string
      type: 'personal' | 'site'
      segment_data: SegmentData
    }) => {
      const response: SavedSegment & { segment_data: SegmentDataFromApi } =
        await mutation(`/api/${encodeURIComponent(site.domain)}/segments`, {
          method: 'POST',
          body: {
            name,
            type,
            segment_data: toApiSegmentData(segment_data)
          }
        })
      return handleSegmentResponse(response)
    },
    onSuccess: async (segment) => {
      addOne(segment)
      queryClient.invalidateQueries({ queryKey: ['segments'] })
      navigate({
        search: getSearchToSetSegmentFilter(segment, {
          omitAllOtherFilters: true
        }),
        state: {
          expandedSegment: null
        }
      })
      setModal(null)
      showToast({ message: 'Segment created' })
    }
  })
}

export function usePatchSegment() {
  const { updateOne } = useSegmentsContext()
  const navigate = useAppNavigate()
  const queryClient = useQueryClient()
  const site = useSiteContext()
  const { setModal } = useRoutelessModalsContext()

  return useMutation({
    mutationFn: async ({
      id,
      name,
      type,
      segment_data
    }: Pick<SavedSegment, 'id'> &
      Partial<Pick<SavedSegment, 'name' | 'type'>> & {
        segment_data?: SegmentData
      }) => {
      const response: SavedSegment & { segment_data: SegmentDataFromApi } =
        await mutation(
          `/api/${encodeURIComponent(site.domain)}/segments/${id}`,
          {
            method: 'PATCH',
            body: {
              name,
              type,
              ...(segment_data && {
                segment_data: toApiSegmentData(segment_data)
              })
            }
          }
        )

      return handleSegmentResponse(response)
    },
    onSuccess: async (segment) => {
      updateOne(segment)
      queryClient.invalidateQueries({ queryKey: ['segments'] })
      navigate({
        search: getSearchToSetSegmentFilter(segment, {
          omitAllOtherFilters: true
        }),
        state: {
          expandedSegment: null
        }
      })
      setModal(null)
      showToast({ message: 'Segment updated' })
    }
  })
}

export function useDeleteSegment() {
  const { removeOne } = useSegmentsContext()
  const navigate = useAppNavigate()
  const queryClient = useQueryClient()
  const site = useSiteContext()
  const { setModal } = useRoutelessModalsContext()

  return useMutation({
    mutationFn: async ({ id }: Pick<SavedSegment, 'id'>) => {
      const response: SavedSegment & { segment_data: SegmentDataFromApi } =
        await mutation(
          `/api/${encodeURIComponent(site.domain)}/segments/${id}`,
          {
            method: 'DELETE'
          }
        )
      return handleSegmentResponse(response)
    },
    onSuccess: (segment): void => {
      removeOne(segment)
      queryClient.invalidateQueries({ queryKey: ['segments'] })
      navigate({
        search: (s) => ({
          ...s,
          filters: null,
          labels: null
        }),
        state: {
          expandedSegment: null
        }
      })
      setModal(null)
      showToast({ message: 'Segment deleted' })
    }
  })
}
