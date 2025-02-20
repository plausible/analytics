/* @format */
import React, { createContext, ReactNode, useContext } from 'react'

export enum Role {
  owner = 'owner',
  admin = 'admin',
  viewer = 'viewer',
  editor = 'editor',
  public = 'public'
}

const userContextDefaultValue = {
  id: null,
  role: null,
  loggedIn: false
} as
  | { loggedIn: false; id: null; role: null }
  | { loggedIn: true; id: number; role: Role }

type UserContextValue = typeof userContextDefaultValue

const UserContext = createContext<UserContextValue>(userContextDefaultValue)

export const useUserContext = () => {
  return useContext(UserContext)
}

export default function UserContextProvider({
  user,
  children
}: {
  user: UserContextValue
  children: ReactNode
}) {
  return <UserContext.Provider value={user}>{children}</UserContext.Provider>
}
