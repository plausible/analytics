import React, { createContext, useMemo, useEffect, useContext, useState, useCallback } from "react";
import { parseQuery } from "./dashboard/query";
import { withRouter } from "react-router-dom";
import { useMountedEffect } from "./dashboard/custom-hooks";
import * as api from './dashboard/api'

const QueryContext = createContext({ query: {}, lastLoadTimestamp: new Date() })

const QueryContextProvider = ({ location, site, children }) => {
    const { search } = location;
    const query = useMemo(() => {
        return parseQuery(search, site)
    }, [search, site])

    const [lastLoadTimestamp, setLastLoadTimestamp] = useState(new Date())
    const updateLastLoadTimestamp = useCallback(() => { setLastLoadTimestamp(new Date()) }, [setLastLoadTimestamp])

    useEffect(() => {
        document.addEventListener('tick', updateLastLoadTimestamp)

        return () => {
            document.removeEventListener('tick', updateLastLoadTimestamp)
        }
    }, [updateLastLoadTimestamp])

    useMountedEffect(() => {
        api.cancelAll()
        updateLastLoadTimestamp()
    }, [])

    return <QueryContext.Provider value={{ query, lastLoadTimestamp }}>{children}</QueryContext.Provider>
};

export default withRouter(QueryContextProvider);

export const useQueryContext = () => { return useContext(QueryContext) }