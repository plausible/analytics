import React, { createContext, useContext } from "react";

const userContextDefaultValue = {
    role: '',
    loggedIn: false,
}

const UserContext = createContext(userContextDefaultValue)

export const useUserContext = () => { return useContext(UserContext) }

export default function UserContextProvider({ role, loggedIn, children }) {
    return <UserContext.Provider value={{role, loggedIn}}>{children}</UserContext.Provider>
};
