import React, {
  createContext,
  ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState
} from 'react'
import {
  NavigationType,
  useLocation,
  useNavigationType
} from 'react-router-dom'
import { useDashboardStateContext } from '../dashboard-state-context'
import { useAppNavigate } from '../navigation/use-app-navigate'
import { Filter, FilterClauseLabels } from '../dashboard-state'
import { cleanLabels, FILTER_OPERATIONS } from '../util/filters'
import { isSegmentFilter } from './segments'

export type FilterEditorPart = 'operator' | 'values'

/**
 * `position` is the index of the pill in `renderedFilters`.
 * Filters without values are not written to the URL: a new filter only
 * appears there when it gets its first value, and a filter is removed from
 * the URL when its last value is removed. While a filter has no values, it
 * is kept as `draft`, so the pill stays until the editor closes.
 */
type EditingFilter = {
  position: number
  part: FilterEditorPart
  draft: Filter | null
  hasPushedHistoryEntry: boolean
}

type FilterEditorContextValue = {
  renderedFilters: Filter[]
  openPosition: number | null
  openPart: FilterEditorPart | null
  open: (position: number, part: FilterEditorPart) => void
  close: () => void
  update: (filter: Filter, labels?: FilterClauseLabels) => void
  remove: (position: number) => void
  add: (filterKey: string) => void
}

const FilterEditorContext = createContext<FilterEditorContextValue | null>(null)

export const useFilterEditorContext = () => {
  const context = useContext(FilterEditorContext)
  if (!context) {
    throw new Error(
      'useFilterEditorContext must be used within FilterEditorContextProvider'
    )
  }
  return context
}

const insertAt = (filters: Filter[], index: number, filter: Filter) => [
  ...filters.slice(0, index),
  filter,
  ...filters.slice(index)
]

const replaceAt = (filters: Filter[], index: number, filter: Filter) =>
  filters.map((f, i) => (i === index ? filter : f))

const removeAt = (filters: Filter[], index: number) =>
  filters.filter((_, i) => i !== index)

const hasValues = ([_operation, _key, clauses]: Filter) => clauses.length > 0

const canHaveMultipleFilters = (filterKey: string) => filterKey === 'goal'

const getNewFilterPosition = (filters: Filter[]) =>
  filters.length && isSegmentFilter(filters[0]) ? 1 : 0

const getUrlIndex = (editing: EditingFilter | null, position: number) =>
  editing?.draft && editing.position < position ? position - 1 : position

export const FilterEditorContextProvider = ({
  children
}: {
  children: ReactNode
}) => {
  const { dashboardState } = useDashboardStateContext()
  const navigate = useAppNavigate()
  const location = useLocation()
  const navigationType = useNavigationType()
  const [editing, setEditingState] = useState<EditingFilter | null>(null)
  const editingRef = useRef<EditingFilter | null>(null)

  const setEditing = useCallback((next: EditingFilter | null) => {
    editingRef.current = next
    setEditingState(next)
  }, [])

  const navigateToFilters = useCallback(
    (
      filters: Filter[],
      {
        replace,
        mergedKey,
        mergedLabels
      }: {
        replace: boolean
        mergedKey?: string
        mergedLabels?: FilterClauseLabels
      }
    ) =>
      navigate({
        search: (search) => ({
          ...search,
          filters,
          labels: cleanLabels(
            filters,
            dashboardState.labels,
            mergedKey,
            mergedLabels
          )
        }),
        replace
      }),
    [navigate, dashboardState.labels]
  )

  /** Closes the editor and returns the URL filters */
  const close = useCallback((): Filter[] => {
    setEditing(null)
    return dashboardState.filters
  }, [setEditing, dashboardState.filters])

  const open = useCallback(
    (position: number, part: FilterEditorPart) => {
      const current = editingRef.current
      if (current?.position === position) {
        setEditing({ ...current, part })
        return
      }
      const index = getUrlIndex(current, position)
      if (close()[index]) {
        setEditing({
          position: index,
          part,
          draft: null,
          hasPushedHistoryEntry: false
        })
      }
    },
    [setEditing, close]
  )

  const update = useCallback(
    (filter: Filter, labels?: FilterClauseLabels) => {
      const current = editingRef.current
      if (!current) {
        return
      }
      if (!hasValues(filter)) {
        if (!current.draft) {
          navigateToFilters(
            removeAt(dashboardState.filters, current.position),
            {
              replace: current.hasPushedHistoryEntry
            }
          )
        }
        setEditing({
          ...current,
          draft: filter,
          hasPushedHistoryEntry: current.hasPushedHistoryEntry || !current.draft
        })
        return
      }
      const filters = current.draft
        ? insertAt(dashboardState.filters, current.position, filter)
        : replaceAt(dashboardState.filters, current.position, filter)
      navigateToFilters(filters, {
        replace: current.hasPushedHistoryEntry,
        mergedKey: filter[1],
        mergedLabels: labels
      })
      setEditing({
        ...current,
        draft: null,
        hasPushedHistoryEntry: true
      })
    },
    [setEditing, dashboardState.filters, navigateToFilters]
  )

  const remove = useCallback(
    (position: number) => {
      const current = editingRef.current
      if (current?.position === position) {
        setEditing(null)
        if (!current.draft) {
          navigateToFilters(removeAt(dashboardState.filters, position), {
            replace: current.hasPushedHistoryEntry
          })
        }
        return
      }
      const index = getUrlIndex(current, position)
      navigateToFilters(removeAt(close(), index), { replace: false })
    },
    [setEditing, close, dashboardState.filters, navigateToFilters]
  )

  const add = useCallback(
    (filterKey: string) => {
      const filters = close()
      const existingIndex = canHaveMultipleFilters(filterKey)
        ? -1
        : filters.findIndex(([_operation, key]) => key === filterKey)
      if (existingIndex >= 0) {
        setEditing({
          position: existingIndex,
          part: 'values',
          draft: null,
          hasPushedHistoryEntry: false
        })
        return
      }
      setEditing({
        position: getNewFilterPosition(filters),
        part: 'values',
        draft: [FILTER_OPERATIONS.is, filterKey, []],
        hasPushedHistoryEntry: false
      })
    },
    [setEditing, close]
  )

  // the open editor belongs to one history entry, so back and forward close it
  useEffect(() => {
    if (navigationType === NavigationType.Pop) {
      setEditing(null)
    }
  }, [setEditing, location.key, navigationType])

  const renderedFilters = useMemo(
    () =>
      editing?.draft
        ? insertAt(dashboardState.filters, editing.position, editing.draft)
        : dashboardState.filters,
    [dashboardState.filters, editing]
  )

  const value = useMemo(
    () => ({
      renderedFilters,
      openPosition: editing?.position ?? null,
      openPart: editing?.part ?? null,
      open,
      close,
      update,
      remove,
      add
    }),
    [renderedFilters, editing, open, close, update, remove, add]
  )

  return (
    <FilterEditorContext.Provider value={value}>
      {children}
    </FilterEditorContext.Provider>
  )
}
