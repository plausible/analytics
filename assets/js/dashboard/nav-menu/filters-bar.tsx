import React from "react"
import { useQueryContext } from "../query-context"
import { FilterPillsList } from "./filter-pills-list";

export const FiltersBar = () => {
    const {query} = useQueryContext();
    if (query.filters.length === 0) {return null}
    return <FilterPillsList></FilterPillsList>
}