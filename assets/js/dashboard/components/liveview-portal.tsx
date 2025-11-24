import React from 'react'

type LiveViewPortalProps = {
  id: string
  className?: string
}

export const LiveViewPortal = React.memo(
  function ({ id, className }: LiveViewPortalProps) {
    return (
      <div
        id={id}
        className={className}
        style={{ width: '100%', border: '0' }}
      />
    )
  },
  () => true
)
