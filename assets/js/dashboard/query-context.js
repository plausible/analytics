import React, { createContext, useMemo, useEffect, useContext, useState, useCallback } from "react";
import { parseQuery } from "./query";
import { withRouter } from "react-router-dom";
import { useMountedEffect } from "./custom-hooks";
import * as api from './api'
import { useSiteContext } from "./site-context";

const queryContextDefaultValue = { query: {}, lastLoadTimestamp: new Date() }

const QueryContext = createContext(queryContextDefaultValue)

export const useQueryContext = () => { return useContext(QueryContext) }

function QueryContextProvider({ location, children }) {
    const site = useSiteContext();
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
