import React, { ReactNode } from 'react'
import { act, renderHook } from '@testing-library/react'
import { useNavigate } from 'react-router-dom'
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

test('the editor closes when the URL filters change while it is open', () => {
  const { result } = renderEditor([page])

  act(() => result.current.editor.add('hostname'))
  act(() => result.current.editor.update(hostname))
  expect(result.current.urlFilters).toEqual([hostname, page])

  act(() => result.current.navigate(-1))

  expect(result.current.urlFilters).toEqual([page])
  expect(result.current.editor.openPosition).toBeNull()
  expect(result.current.editor.renderedFilters).toEqual([page])
})
