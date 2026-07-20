import React, { useEffect } from 'react'
import { useAppNavigate } from '../navigation/use-app-navigate'

type VerificationFinishedDetail = {
  /**
   * Exact query param names to drop from the URL when verification banner
   * disappears. See: PlausibleWeb.Live.Components.VerificationBanner.query_params/0
   */
  queryParams: string[]
}

export const VERIFICATION_FINISHED_EVENT = 'verification-finished'

/**
 * Renders the portal target into which the verification LiveView (see
 * lib/plausible_web/live/components/verification.ex) gets teleported.
 * Also helps that LiveView out with cleaning up after itself: clearing
 * its one-time query params through React Router.
 */
export const VerificationLiveViewPortal = React.memo(() => {
  const navigate = useAppNavigate()

  useEffect(() => {
    function handleVerificationFinished(event: Event) {
      const { queryParams } = (event as CustomEvent<VerificationFinishedDetail>)
        .detail

      navigate({
        search: (search) => {
          const nextSearch = { ...search }
          queryParams.forEach((param) => delete nextSearch[param])
          return nextSearch
        }
      })
    }

    window.addEventListener(
      VERIFICATION_FINISHED_EVENT,
      handleVerificationFinished
    )

    return () =>
      window.removeEventListener(
        VERIFICATION_FINISHED_EVENT,
        handleVerificationFinished
      )
  }, [navigate])

  return <div id="verification-portal-target"></div>
})
