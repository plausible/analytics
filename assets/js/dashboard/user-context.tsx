/* @format */
import React, { createContext, ReactNode, useContext } from 'react'

export enum Role {
  owner = 'owner',
  admin = 'admin',
  viewer = 'viewer',
  editor = 'editor'
}

const userContextDefaultValue = {
  role: Role.viewer,
  loggedIn: false
}

const UserContext = createContext(userContextDefaultValue)

export const useUserContext = () => {
  return useContext(UserContext)
}

export default function UserContextProvider({
  role,
  loggedIn,
  children
}: {
  role: Role
  loggedIn: boolean
  children: ReactNode
}) {
  return (
    <UserContext.Provider value={{ role, loggedIn }}>
      {children}
    </UserContext.Provider>
  )
}
