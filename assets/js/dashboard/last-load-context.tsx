import React, {
  createContext,
  useEffect,
  useContext,
  useState,
  useCallback,
  ReactNode
} from 'react'
import { useMountedEffect } from './custom-hooks'

const LastLoadContext = createContext(new Date())

export const useLastLoadContext = () => {
  return useContext(LastLoadContext)
}

export default function LastLoadContextProvider({
  children
}: {
  children: ReactNode
}) {
  const [timestamp, setTimestamp] = useState(new Date())

  const updateTimestamp = useCallback(() => {
    setTimestamp(new Date())
  }, [setTimestamp])

  useEffect(() => {
    document.addEventListener('tick', updateTimestamp)

    return () => {
      document.removeEventListener('tick', updateTimestamp)
    }
  }, [updateTimestamp])

  useMountedEffect(() => {
    updateTimestamp()
  }, [])

  return (
    <LastLoadContext.Provider value={timestamp}>
      {children}
    </LastLoadContext.Provider>
  )
}
