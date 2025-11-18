import React from 'react'
import { LiveViewIframe } from '../components/liveview-iframe'
import { useQueryContext } from '../query-context'
import { useSiteContext } from '../site-context'
import * as url from '../util/url'
import * as api from '../api'

export function PagesLive() {
  const { query } = useQueryContext()
  const site = useSiteContext()

  const frameUrl = api.getUrl(url.livePath(site, '/pages'), query)

  function onMessage(data) {
    console.log(data)
  }

  return (
    <LiveViewIframe
      onMessage={onMessage}
      className="w-full h-full border-0 overflow-hidden"
      src={frameUrl}
    />
  )
}
