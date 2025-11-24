import React, { useEffect, useRef, useState } from 'react'
import { useNavigation } from 'react-router-dom'

type LiveViewIframeProps = {
  src: string
  className?: string
  onMessage: (data: object) => void
  minHeight?: number // fallback height
}

export const LiveViewIframe = React.memo(
  function ({
    src,
    className,
    onMessage,
    minHeight = 85
  }: LiveViewIframeProps) {
    const ref = useRef<HTMLIFrameElement>(null)
    const [height, setHeight] = useState(minHeight)
    const navigation = useNavigation()

    useEffect(() => {
      const handleMessage = (ev: MessageEvent) => {
        if (ev.data?.type === 'EMBEDDED_LV_SIZE') {
          setHeight(Math.max(minHeight, Number(ev.data.height) || minHeight))
        } else if (ev.data?.type?.startsWith('EMBEDDED_LV')) {
          onMessage(ev.data)
        }
      }
      window.addEventListener('message', handleMessage)
      return () => window.removeEventListener('message', handleMessage)
    }, [minHeight])

    // useEffect(() => {
    //   const unsubscribe = navigation.addListener('state', () => {})
    //   return unsubscribe
    // }, [navigation])

    return (
      <iframe
        ref={ref}
        src={src}
        style={{ width: '100%', border: '0', height }}
        className={className}
        title="LiveView Widget"
      />
    )
  },
  () => true
)
