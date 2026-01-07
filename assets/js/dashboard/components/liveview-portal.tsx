/**
 * Component used for embedding LiveView components inside React.
 *
 * The content of the portal is completely excluded from React re-renders with
 * a hardwired `React.memo`.
 */

import React from 'react'
import classNames from 'classnames'
import { ReportHeader } from '../stats/reports/report-header'
import { ReportLayout } from '../stats/reports/report-layout'
import { TabButton, TabWrapper } from './tabs'
import { MoreLinkState } from '../stats/more-link-state'
import MoreLink from '../stats/more-link'

const MIN_HEIGHT = 356

type LiveViewPortalProps = {
  id: string
  tabs: { value: string; label: string }[]
  storageKey: string
  className?: string
}

export const LiveViewPortal = React.memo(
  function ({ id, tabs, storageKey, className }: LiveViewPortalProps) {
    const activeTab = localStorage.getItem(storageKey) || 'pages'

    return (
      <div
        id={id}
        className={classNames('group', className)}
        style={{ width: '100%', border: '0', minHeight: MIN_HEIGHT }}
      >
        <div className={'group-has-[[data-phx-teleported]]:hidden'}>
          <ReportLayout>
            <ReportHeader>
              <div className="flex gap-x-3">
                <TabWrapper>
                  {tabs.map(({ value, label }) => (
                    <TabButton
                      key={value}
                      active={activeTab === value}
                      onClick={() => {}}
                    >
                      {label}
                    </TabButton>
                  ))}
                </TabWrapper>
              </div>
              <MoreLink state={MoreLinkState.LOADING} linkProps={undefined} />
            </ReportHeader>
            <div
              className="w-full flex flex-col justify-center"
              style={{ minHeight: `${MIN_HEIGHT}px` }}
            >
              <div className="mx-auto loading">
                <div></div>
              </div>
            </div>
          </ReportLayout>
        </div>
      </div>
    )
  },
  () => true
)
