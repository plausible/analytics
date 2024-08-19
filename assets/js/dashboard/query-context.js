import React, { createContext, useMemo, useEffect, useContext, useState, useCallback } from "react";
import { parseQuery } from "./query";
import { useLocation } from "react-router";
import { useMountedEffect } from "./custom-hooks";
import * as api from './api'
import { useSiteContext } from "./site-context";
import { parseSearch } from "./util/url";

const queryContextDefaultValue = { query: {}, lastLoadTimestamp: new Date() }

const QueryContext = createContext(queryContextDefaultValue)

export const useQueryContext = () => { return useContext(QueryContext) }

export default function QueryContextProvider({ children }) {
    const location = useLocation();
    const site = useSiteContext();
    const searchRecord = useMemo(() => parseSearch(location.search), [location.search]);

    const query = useMemo(() => {
        return parseQuery(searchRecord, site)
    }, [searchRecord, site])
    
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
