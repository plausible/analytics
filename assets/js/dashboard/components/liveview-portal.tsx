/**
 * Component used for embedding LiveView components inside React.
 *
 * The content of the portal is completely excluded from React re-renders with
 * a hardwired `React.memo`.
 */

import React from 'react'
import classNames from 'classnames'

const MIN_HEIGHT = 380

type LiveViewPortalProps = {
  id: string
  className?: string
}

export const LiveViewPortal = React.memo(
  function ({ id, className }: LiveViewPortalProps) {
    return (
      <div
        id={id}
        className={classNames('group', className)}
        style={{ width: '100%', border: '0', minHeight: MIN_HEIGHT }}
      >
        <div
          className="w-full flex flex-col justify-center group-has-[[data-phx-teleported]]:hidden"
          style={{ minHeight: MIN_HEIGHT }}
        >
          <div className="mx-auto loading">
            <div />
          </div>
        </div>
      </div>
    )
  },
  () => true
)
