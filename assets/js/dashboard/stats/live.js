import React from 'react'
import { LiveViewIframe } from '../components/liveview-iframe'
import { useAppNavigate } from '../navigation/use-app-navigate'
import { useQueryContext } from '../query-context'
import { useSiteContext } from '../site-context'
import { cleanLabels, replaceFilterByPrefix } from '../util/filters'
import * as url from '../util/url'
import * as api from '../api'

export function PagesLive() {
  const { query } = useQueryContext()
  const site = useSiteContext()
  const navigate = useAppNavigate()

  const frameUrl = api.getUrl(url.livePath(site, '/pages'), query)

  function applyFilter(filterDefinition) {
    const { prefix, filter, labels } = filterDefinition
    const newFilters = replaceFilterByPrefix(query, prefix, filter)
    const newLabels = cleanLabels(newFilters, query.labels, filter[1], labels)

    navigate({
      search: (search) => ({
        ...search,
        filters: newFilters,
        labels: newLabels
      })
    })
  }

  function onMessage(data) {
    switch (data.type) {
      case 'EMBEDDED_LV_PATCH_FILTER':
        applyFilter(data.filter)
        break
    }
  }

  return (
    <LiveViewIframe
      onMessage={onMessage}
      className="w-full h-full border-0 overflow-hidden"
      src={frameUrl}
    />
  )
}
