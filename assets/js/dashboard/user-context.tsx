import React, { createContext, ReactNode, useContext } from 'react'

export enum Role {
  owner = 'owner',
  admin = 'admin',
  viewer = 'viewer',
  editor = 'editor',
  public = 'public',
  billing = 'billing'
}

const userContextDefaultValue = {
  loggedIn: false,
  id: null,
  role: Role.public,
  team: {
    identifier: null,
    hasConsolidatedView: false
  }
} as
  | { loggedIn: false; id: null; role: Role; team: { identifier: null; hasConsolidatedView: false } }
  | { loggedIn: true; id: number; role: Role; team: { identifier: string | null; hasConsolidatedView: boolean } }

export type UserContextValue = typeof userContextDefaultValue

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
