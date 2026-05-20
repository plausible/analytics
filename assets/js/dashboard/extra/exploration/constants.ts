export type ExplorationDirection = 'forward' | 'backward'

type ExplorationDirectionOption = {
  value: ExplorationDirection
  label: string
}
export const DIRECTION: { [label: string]: ExplorationDirection } = {
  FORWARD: 'forward',
  BACKWARD: 'backward'
}

export const DIRECTION_OPTIONS: ExplorationDirectionOption[] = [
  { value: DIRECTION.FORWARD, label: 'Starting point' },
  { value: DIRECTION.BACKWARD, label: 'End point' }
]

export const PAGE_FILTER_KEYS = ['page', 'entry_page', 'exit_page']

export const INITIAL_VISIBLE_CANDIDATES = 10
export const SHOW_MORE_INCREMENT = 10
export const MIN_GRID_COLUMNS = 3
