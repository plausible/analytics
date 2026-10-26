import React, {
  createContext,
  ReactNode,
  useCallback,
  useContext,
  useState
} from 'react'
import type { JourneyStep } from './extra/exploration/journey'
import type { FunnelType } from './extra/funnel/metrics'

export type SavedFunnel = {
  id: number
  name: string
  steps_count: number
}

// Where the funnel builder is headed: a brand new funnel, or editing
// a saved one by id. Kept in the `build_funnel` search param.
export type FunnelBuildTarget = 'new' | number

export const FUNNEL_BUILD_SEARCH_PARAM = 'build_funnel'

export function parseFunnelBuildTarget(
  value: unknown
): FunnelBuildTarget | null {
  if (value === 'new') return 'new'
  const id =
    typeof value === 'number' || typeof value === 'string' ? Number(value) : NaN
  return Number.isInteger(id) && id > 0 ? id : null
}

// What a new funnel starts out as, e.g. an explored journey
export type FunnelDraft = {
  steps: JourneyStep[]
  funnelType?: FunnelType
}

export type FunnelBuilderControls = {
  target: FunnelBuildTarget | null
  draft: FunnelDraft | null
  start: (target: FunnelBuildTarget, draft?: FunnelDraft) => void
  stop: () => void
  onSaved: (funnel: SavedFunnel) => void
}

type ChangeFunnelState = (funnel: SavedFunnel) => void

const initialValue: {
  funnels: SavedFunnel[]
  addOne: ChangeFunnelState
  updateOne: ChangeFunnelState
  removeOne: ChangeFunnelState
} = {
  funnels: [],
  addOne: () => {},
  updateOne: () => {},
  removeOne: () => {}
}

const FunnelsContext = createContext(initialValue)

export const useFunnelsContext = () => {
  return useContext(FunnelsContext)
}

// Holds the list of saved funnels, preloaded with the page and kept up to date
// as funnels are created, edited and deleted from the dashboard.
export const FunnelsContextProvider = ({
  preloadedFunnels,
  children
}: {
  preloadedFunnels: SavedFunnel[]
  children: ReactNode
}) => {
  const [funnels, setFunnels] = useState(preloadedFunnels)

  const addOne: ChangeFunnelState = useCallback(
    ({ id, name, steps_count }) =>
      setFunnels((current) => [{ id, name, steps_count }, ...current]),
    []
  )

  const updateOne: ChangeFunnelState = useCallback(
    ({ id, name, steps_count }) =>
      setFunnels((current) =>
        current.map((f) => (f.id === id ? { id, name, steps_count } : f))
      ),
    []
  )

  const removeOne: ChangeFunnelState = useCallback(
    ({ id }) => setFunnels((current) => current.filter((f) => f.id !== id)),
    []
  )

  return (
    <FunnelsContext.Provider value={{ funnels, addOne, updateOne, removeOne }}>
      {children}
    </FunnelsContext.Provider>
  )
}
