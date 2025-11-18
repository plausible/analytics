import React, { useEffect, useRef, useState } from 'react'

type LiveViewIframeProps = {
  src: string
  className?: string
  onMessage: (data: object) => void
  minHeight?: number // fallback height
}

export function LiveViewIframe({
  src,
  className,
  onMessage,
  minHeight = 85
}: LiveViewIframeProps) {
  const ref = useRef<HTMLIFrameElement>(null)
  const [height, setHeight] = useState(minHeight)

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

  return (
    <iframe
      ref={ref}
      src={src}
      style={{ width: '100%', border: '0', height }}
      className={className}
      title="LiveView Widget"
    />
  )
}
