import { Filter } from '../query'
import { FILTER_OPERATIONS } from './filters'

export const isPageViewGoal = (goalName: string) => {
  goalName.startsWith('Visit ')
}

export const SPECIAL_GOALS = {
  '404': { title: '404 Pages', prop: 'path' },
  'Outbound Link: Click': { title: 'Outbound Links', prop: 'url' },
  'Cloaked Link: Click': { title: 'Cloaked Links', prop: 'url' },
  'File Download': { title: 'File Downloads', prop: 'url' },
  'WP Search Queries': {
    title: 'WordPress Search Queries',
    prop: 'search_query'
  },
  'WP Form Completions': { title: 'WordPress Form Completions', prop: 'path' }
}

export function isSpecialGoal(
  goalName: string | number
): goalName is keyof typeof SPECIAL_GOALS {
  return goalName in SPECIAL_GOALS
}

export function getSpecialGoal(goalFilter: Filter) {
  const [operation, _filterKey, clauses] = goalFilter
  if (operation === FILTER_OPERATIONS.is && clauses.length == 1) {
    const goalName = clauses[0]
    return isSpecialGoal(goalName) ? SPECIAL_GOALS[goalName] : null
  }
  return null
}
