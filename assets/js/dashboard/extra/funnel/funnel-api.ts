import { useMutation, useQueryClient } from '@tanstack/react-query'
import * as api from '../../api'
import { showToast } from '../../components/toast'
import { useSiteContext } from '../../site-context'
import { SavedFunnel, useFunnelsContext } from '../../funnels-context'
import { FunnelType } from './metrics'

export type GoalKind = 'scroll' | 'props' | 'revenue'

type DynamicStepProperties = {
  scroll_threshold?: number
  custom_props?: Record<string, string>
  currency?: string | null
}

// Step as accepted by the API: a reference to a goal or a dynamic step
export type FunnelStepInput =
  | { goal_id: number }
  | ({ event_name: string } & DynamicStepProperties)
  | ({ page_path: string } & DynamicStepProperties)

export type FunnelDefinitionStep = {
  goal_id: number | null
  goal_kind: GoalKind | null
  label: string
  event_name: string | null
  page_path: string | null
  scroll_threshold: number
  custom_props: Record<string, string>
  currency: string | null
}

export type FunnelDefinition = SavedFunnel & {
  funnel_type: FunnelType
  steps: FunnelDefinitionStep[]
}

type SavedFunnelResponse = SavedFunnel & { funnel_type: FunnelType }

function funnelsPath(domain: string, id?: number): string {
  const base = `/api/${encodeURIComponent(domain)}/funnels`
  return id === undefined ? base : `${base}/${id}`
}

export function fetchFunnelDefinition(
  domain: string,
  id: number
): Promise<FunnelDefinition> {
  return api.get(funnelsPath(domain, id))
}

export function useCreateFunnel() {
  const site = useSiteContext()
  const { addOne } = useFunnelsContext()
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (input: {
      name: string
      funnel_type: FunnelType
      steps: FunnelStepInput[]
    }): Promise<SavedFunnelResponse> =>
      api.mutation(funnelsPath(site.domain), { method: 'POST', body: input }),
    onSuccess: (funnel) => {
      addOne(funnel)
      queryClient.invalidateQueries({ queryKey: ['funnel'] })
      showToast({ message: 'Funnel saved' })
    }
  })
}

export function useUpdateFunnel() {
  const site = useSiteContext()
  const { updateOne } = useFunnelsContext()
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({
      id,
      ...input
    }: {
      id: number
      name?: string
      funnel_type?: FunnelType
      steps?: FunnelStepInput[]
    }): Promise<SavedFunnelResponse> =>
      api.mutation(funnelsPath(site.domain, id), {
        method: 'PATCH',
        body: input
      }),
    onSuccess: (funnel) => {
      updateOne(funnel)
      queryClient.invalidateQueries({ queryKey: ['funnel'] })
      showToast({ message: 'Funnel updated' })
    }
  })
}

export function useDeleteFunnel() {
  const site = useSiteContext()
  const { removeOne } = useFunnelsContext()

  return useMutation({
    mutationFn: ({ id }: { id: number }): Promise<SavedFunnelResponse> =>
      api.mutation(funnelsPath(site.domain, id), { method: 'DELETE' }),
    onSuccess: (funnel) => {
      removeOne(funnel)
      showToast({ message: 'Funnel deleted' })
    }
  })
}
