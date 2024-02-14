import React, { useEffect, useState, useMemo } from 'react'
import { withRouter } from "react-router-dom";

import { FILTER_OPERATIONS } from "../../util/filters";
import { parseQuery } from '../../query'
import { siteBasePath } from '../../util/url'
import { toFilterQuery, parseQueryPropsFilter } from '../../util/filters';
import { shouldIgnoreKeypress } from '../../keybinding';
import PropFilterRow from './prop-filter-row';

function getFormState(query) {
  if (query.filters['props']) {
    const values = Object.fromEntries(parseQueryPropsFilter(query, 'props').map((value, index) => [index, value]))

    return {
      entries: Object.keys(values).sort(),
      values
    }
  } else {
    return {
      entries: [0],
      values: {
        0: {
          propKey: null,
          type: FILTER_OPERATIONS.is,
          clauses: []
        }
      }
    }
  }
}

function PropFilterModal(props) {
  const query = parseQuery(props.location.search, props.site)
  const [formState, setFormState] = useState(getFormState(query))

  const selectedPropKeys = useMemo(() => Object.values(formState.values).map((value) => value.propKey), [formState])

  function onPropKeySelect(id, selectedOptions) {
    const newPropKey = selectedOptions.length === 0 ? null : selectedOptions[0]
    setFormState(prevState => ({
      ...prevState,
      values: {
        ...prevState.values,
        [id]: {
          ...prevState.values[id],
          propKey: newPropKey,
          clauses: []
        }
      }
    }))
  }

  function onPropValueSelect(id, selection) {
    setFormState(prevState => ({
      ...prevState,
      values: {
        ...prevState.values,
        [id]: {
          ...prevState.values[id],
          clauses: selection
        }
      }
    }))
  }

  function onFilterTypeSelect(id, newType) {
    setFormState(prevState => ({
      ...prevState,
      values: {
        ...prevState.values,
        [id]: {
          ...prevState.values[id],
          type: newType
        }
      }
    }))
  }

  function onPropAdd() {
    setFormState(prevState => {
      const id = prevState.entries[prevState.entries.length - 1] + 1
      return {
        entries: prevState.entries.concat([id]),
        values: {
          ...prevState.values,
          [id]: {
            propKey: null,
            type: FILTER_OPERATIONS.is,
            clauses: []
          }
        }
      }
    })
  }

  function onPropDelete(id) {
    setFormState(prevState => {
      const entries = prevState.entries.filter((entry) => entry != id)
      const values = {...prevState.values}
      delete values[id]

      return { entries, values }
    })
  }

  function isDisabled() {
    return formState.entries.some((id) => !formState.values[id].propKey || formState.values[id].clauses.length == 0)
  }

  function shouldShowClear() {
    return !!query.filters['props']
  }

  function handleSubmit() {
    const formFilters = Object.fromEntries(
      Object.entries(formState.values)
        .map(([_, {propKey, type, clauses}]) => [propKey.value, toFilterQuery(type, clauses)])
    )
    selectFiltersAndCloseModal(JSON.stringify(formFilters))
  }

  function selectFiltersAndCloseModal(filterString) {
    const queryString = new URLSearchParams(window.location.search)

    if (filterString) {
      queryString.set('props', filterString)
    } else {
      queryString.delete('props')
    }

    props.history.replace({ pathname: siteBasePath(props.site), search: queryString.toString() })
  }

  const handleKeydown = (e) => {
    if (shouldIgnoreKeypress(e)) return

    if (e.target.tagName === 'BODY' && e.key === 'Enter') {
      handleSubmit()
    }
  }

  useEffect(() => {
    document.addEventListener('keydown', handleKeydown)
    return () => {
      document.removeEventListener('keydown', handleKeydown)
    }
  }, [handleSubmit])

  return (
    <>
      <h1 className="text-xl font-bold dark:text-gray-100">Filter by Property</h1>

      <div className="mt-4 border-b border-gray-300"></div>
      <main className="modal__content">
        <form className="flex flex-col" onSubmit={handleSubmit}>
          {formState.entries.map((id) => (
              <PropFilterRow
                key={id}
                id={id}
                site={props.site}
                query={query}
                {...formState.values[id]}
                showDelete={formState.entries.length > 1}
                selectedPropKeys={selectedPropKeys}
                onPropKeySelect={onPropKeySelect}
                onPropValueSelect={onPropValueSelect}
                onFilterTypeSelect={onFilterTypeSelect}
                onPropDelete={onPropDelete}
              />
          ))}

          <div className="mt-6">
            <a className="underline text-indigo-500 text-sm cursor-pointer" onClick={onPropAdd}>
              + Add another
            </a>
          </div>

          <div className="mt-6 flex items-center justify-start">
            <button
              type="submit"
              className="button"
              disabled={isDisabled()}
            >
              Apply Filter
            </button>

            {shouldShowClear() && (
              <button
                type="button"
                className="ml-2 button px-4 flex bg-red-500 dark:bg-red-500 hover:bg-red-600 dark:hover:bg-red-700 items-center"
                onClick={() => { selectFiltersAndCloseModal(null) }}
              >
                <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                Remove filter
              </button>
            )}
          </div>
        </form>
      </main>
    </>
  )
}

export default withRouter(PropFilterModal)
