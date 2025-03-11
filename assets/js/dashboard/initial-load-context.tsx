/** @format */
import React, { createContext, ReactNode, useContext, useState } from 'react'
import { remapFromApiFilters } from './util/filters'
import { Filter } from './query'

export function parseInitialLoadDataFromDataset(dataset: DOMStringMap) {
  return {
    resolvedFilters: remapFromApiFilters(JSON.parse(dataset.resolvedFilters!))
  }
}

type InitialLoadData = { resolvedFilters: Filter[] }

const initialLoadContextDefaultValue: InitialLoadData = {
  resolvedFilters: []
}

const InitialLoadContext = createContext(initialLoadContextDefaultValue)

export const useInitialLoadContext = () => {
  return useContext(InitialLoadContext)
}

export const InitialLoadContextProvider = ({
  data,
  children
}: {
  data: InitialLoadData
  children: ReactNode
}) => {
  const [resolvedFilters] = useState(data.resolvedFilters)
  return (
    <InitialLoadContext.Provider value={{ resolvedFilters }}>
      {children}
    </InitialLoadContext.Provider>
  )
}
