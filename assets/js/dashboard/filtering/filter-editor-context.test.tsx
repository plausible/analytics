import React, { ReactNode } from 'react'
import { act, renderHook } from '@testing-library/react'
import { useNavigate } from 'react-router'
import { TestContextProviders } from '../../../test-utils/app-context-providers'
import { useDashboardStateContext } from '../dashboard-state-context'
import { Filter } from '../dashboard-state'
import { getRouterBasepath } from '../router'
import { stringifySearch } from '../util/url-search-params'
import {
  FilterEditorContextProvider,
  useFilterEditorContext
} from './filter-editor-context'

const domain = 'dummy.site'

const renderEditor = (filters: Filter[]) =>
  renderHook(
    () => ({
      editor: useFilterEditorContext(),
      urlFilters: useDashboardStateContext().dashboardState.filters,
      navigate: useNavigate()
    }),
    {
      wrapper: ({ children }: { children: ReactNode }) => (
        <TestContextProviders
          siteOptions={{ domain }}
          routerProps={{
            initialEntries: [
              {
                pathname: getRouterBasepath({ domain, shared: false }),
                search: stringifySearch({ filters })
              }
            ]
          }}
        >
          <FilterEditorContextProvider>{children}</FilterEditorContextProvider>
        </TestContextProviders>
      )
    }
  )

const page: Filter = ['is', 'page', ['/blog']]
const source: Filter = ['is', 'source', ['Google']]
const hostname: Filter = ['is', 'hostname', ['example.com']]

test('opening a pill while a new filter without values is open opens the correct filter', () => {
  const { result } = renderEditor([page, source])

  act(() => result.current.editor.add('hostname'))
  expect(result.current.editor.renderedFilters).toEqual([
    ['is', 'hostname', []],
    page,
    source
  ])

  act(() => result.current.editor.open(2, 'values'))
  expect(result.current.editor.renderedFilters).toEqual([page, source])
  expect(result.current.editor.openPosition).toBe(1)
})

test('removing a pill while an emptied filter is open removes the correct filter', () => {
  const { result } = renderEditor([page, source, hostname])

  act(() => result.current.editor.open(0, 'values'))
  act(() => result.current.editor.update(['is', 'page', []]))
  act(() => result.current.editor.remove(2))

  expect(result.current.urlFilters).toEqual([source])
  expect(result.current.editor.openPosition).toBeNull()
})

test('removing the last value removes the filter from the URL at once and keeps the pill open', () => {
  const { result } = renderEditor([page, source])

  act(() => result.current.editor.open(0, 'values'))
  act(() => result.current.editor.update(['is', 'page', []]))
  expect(result.current.urlFilters).toEqual([source])
  expect(result.current.editor.renderedFilters).toEqual([
    ['is', 'page', []],
    source
  ])
  expect(result.current.editor.openPosition).toBe(0)

  act(() => result.current.editor.update(page))
  expect(result.current.urlFilters).toEqual([page, source])
})

test('the editor closes when the browser goes back to the filter before its values were removed', () => {
  const { result } = renderEditor([page])

  act(() => result.current.editor.open(0, 'values'))
  act(() => result.current.editor.update(['is', 'page', []]))
  expect(result.current.urlFilters).toEqual([])

  act(() => result.current.navigate(-1))

  expect(result.current.urlFilters).toEqual([page])
  expect(result.current.editor.openPosition).toBeNull()
  expect(result.current.editor.renderedFilters).toEqual([page])
})

test('the editor closes when the browser goes back to before the new filter was added', () => {
  const { result } = renderEditor([page])

  act(() => result.current.editor.add('hostname'))
  act(() => result.current.editor.update(hostname))
  expect(result.current.urlFilters).toEqual([hostname, page])

  act(() => result.current.navigate(-1))

  expect(result.current.urlFilters).toEqual([page])
  expect(result.current.editor.openPosition).toBeNull()
  expect(result.current.editor.renderedFilters).toEqual([page])
})

test('the editor closes when the browser goes back to before a value was added', () => {
  const { result } = renderEditor([page])

  act(() => result.current.editor.open(0, 'values'))
  act(() => result.current.editor.update(['is', 'page', ['/blog', '/docs']]))
  act(() => result.current.navigate(-1))

  expect(result.current.urlFilters).toEqual([page])
  expect(result.current.editor.openPosition).toBeNull()
  expect(result.current.editor.renderedFilters).toEqual([page])
})

test('a change after the browser goes back adds a new history entry', () => {
  const { result } = renderEditor([page])

  act(() => result.current.editor.open(0, 'values'))
  act(() => result.current.editor.update(['is', 'page', ['/blog', '/docs']]))
  act(() => result.current.navigate(-1))
  act(() => result.current.editor.open(0, 'values'))
  act(() => result.current.editor.update(['is', 'page', ['/blog', '/about']]))
  act(() => result.current.navigate(-1))

  expect(result.current.urlFilters).toEqual([page])
})

test('an open pill shows the new URL filter when the URL changes', () => {
  const { result } = renderEditor([page])
  const otherPage: Filter = ['is', 'page', ['/docs']]

  act(() => result.current.editor.open(0, 'values'))
  act(() =>
    result.current.navigate({
      search: stringifySearch({ filters: [otherPage] })
    })
  )

  expect(result.current.editor.renderedFilters).toEqual([otherPage])
})
