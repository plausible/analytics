import React, { useRef, useState } from 'react'
import { Popover, Transition } from '@headlessui/react'
import { EllipsisVerticalIcon } from '@heroicons/react/24/outline'
import classNames from 'classnames'

import * as storage from '../../util/storage'
import {
  hasConversionGoalFilter,
  isRealTimeDashboard
} from '../../util/filters'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useSiteContext } from '../../site-context'
import { ReportLayout } from '../reports/report-layout'
import { ReportHeader } from '../reports/report-header'
import { TabButton, TabWrapper } from '../../components/tabs'
import MoreLink from '../more-link'
import { MoreLinkState } from '../more-link-state'
import { QueryApiResponse } from '../../api'
import ImportedWarningBubble from '../imported-warning-bubble'
import {
  BREAKDOWN_REPORTS,
  BreakdownReportKey
} from '../reports/reports-config'
import {
  DimensionCellWithBar,
  IndexBreakdown,
  DimensionCellWithBarProps
} from '../reports/index-breakdown'
import { defaultGetFilterInfo, GetFilterInfo } from '../breakdowns'
import { Filter } from '../../dashboard-state'
import { externalLinkForPage, trimURL } from '../../util/url'
import { IndexExternalLink } from './external-link'
import {
  popover,
  BlurMenuButtonOnEscape,
  SelectedCheckmark
} from '../../components/popover'

const BAR_COLOR = 'bg-orange-50 group-hover/row:bg-orange-100'
const MAX_DIMENSION_LENGTH = 70

type BreakdownMode = 'path' | 'hostname'
type TabKey =
  | BreakdownReportKey.pages
  | BreakdownReportKey.entryPages
  | BreakdownReportKey.exitPages

const BREAKDOWN_MODE_OPTIONS: Array<{ value: BreakdownMode; label: string }> = [
  { value: 'path', label: 'Path' },
  { value: 'hostname', label: 'URL' } // URL is more suitable for user-facing label
]

function getReportKey(tab: TabKey, mode: BreakdownMode): BreakdownReportKey {
  if (mode === 'hostname') {
    switch (tab) {
      case BreakdownReportKey.pages:
        return BreakdownReportKey.pagesWithHostname
      case BreakdownReportKey.entryPages:
        return BreakdownReportKey.entryPagesWithHostname
      case BreakdownReportKey.exitPages:
        return BreakdownReportKey.exitPagesWithHostname
    }
  }
  return tab
}

export default function Pages() {
  const { dashboardState } = useDashboardStateContext()
  const site = useSiteContext()

  const tabStorageKey = `pageTab__${site.domain}`
  const modeStorageKey = `pageBreakdownMode__${site.domain}`
  const [tab, setTab] = useState<TabKey>(
    initTab(storage.getItem(tabStorageKey))
  )
  const [breakdownMode, setBreakdownMode] = useState<BreakdownMode>(() =>
    storage.getItem(modeStorageKey) === 'hostname' ? 'hostname' : 'path'
  )
  const [currentData, setCurrentData] = useState<QueryApiResponse | null>(null)

  const reportKey = getReportKey(tab, breakdownMode)
  const reportConfig = BREAKDOWN_REPORTS[reportKey]

  const metrics = reportConfig.getMetrics({
    isRealtime: isRealTimeDashboard(dashboardState),
    hasConversionGoalFilter: hasConversionGoalFilter(dashboardState)
  })

  function switchTab(newTab: TabKey) {
    storage.setItem(tabStorageKey, newTab)
    setTab(newTab)
  }

  function selectBreakdownMode(mode: BreakdownMode) {
    storage.setItem(modeStorageKey, mode)
    setBreakdownMode(mode)
  }

  const moreLinkState = currentData
    ? currentData.results.length > 0
      ? MoreLinkState.READY
      : MoreLinkState.HIDDEN
    : MoreLinkState.LOADING

  const DimensionElement =
    breakdownMode === 'hostname'
      ? HOSTNAME_DIMENSION_CELLS[tab]
      : PathDimensionCell

  return (
    <ReportLayout testId="report-pages" className="overflow-x-hidden">
      <ReportHeader>
        <div className="flex gap-x-3">
          <TabWrapper>
            {(
              [
                {
                  label: hasConversionGoalFilter(dashboardState)
                    ? 'Conversion pages'
                    : 'Top pages',
                  value: BreakdownReportKey.pages
                },
                { label: 'Entry pages', value: BreakdownReportKey.entryPages },
                { label: 'Exit pages', value: BreakdownReportKey.exitPages }
              ] as const
            ).map(({ value, label }) => (
              <TabButton
                key={value}
                active={tab === value}
                onClick={() => switchTab(value)}
              >
                {label}
              </TabButton>
            ))}
          </TabWrapper>
          <ImportedWarningBubble queryApiResponse={currentData} />
        </div>
        <div className="flex items-start gap-x-3">
          <MoreLink
            state={moreLinkState}
            linkProps={{
              path: reportConfig.detailsPath,
              search: (search: string) => search
            }}
          />
          <PagesBreakdownMenu
            breakdownMode={breakdownMode}
            onSelect={selectBreakdownMode}
          />
        </div>
      </ReportHeader>
      <IndexBreakdown
        key={reportKey}
        metrics={metrics}
        dimensions={reportConfig.dimensions}
        dimensionLabel={reportConfig.dimensionLabel}
        alwaysOnFilters={reportConfig.alwaysOnFilters}
        DimensionElement={DimensionElement}
        onDataReady={setCurrentData}
      />
    </ReportLayout>
  )
}

function PagesBreakdownMenu({
  breakdownMode,
  onSelect
}: {
  breakdownMode: BreakdownMode
  onSelect: (mode: BreakdownMode) => void
}) {
  const buttonRef = useRef<HTMLButtonElement>(null)

  return (
    <Popover className="relative">
      {({ close }) => (
        <>
          <BlurMenuButtonOnEscape targetRef={buttonRef} />
          <Popover.Button
            ref={buttonRef}
            className={classNames(
              'relative flex rounded !text-gray-500 dark:!text-gray-400 hover:!text-gray-600 dark:hover:!text-gray-300 transition-colors duration-150 before:absolute before:inset-[-8px]',
              popover.toggleButton.classNames.linkLike,
              'justify-center'
            )}
            title="Breakdown options"
            aria-label="Breakdown options"
          >
            <EllipsisVerticalIcon className="size-4.5" />
          </Popover.Button>
          <Transition
            as="div"
            {...popover.transition.props}
            className={classNames(
              popover.transition.classNames.right,
              'mt-2 min-w-48'
            )}
          >
            <Popover.Panel className={popover.panel.classNames.roundedSheet}>
              <p className="uppercase text-xs font-medium text-gray-500 dark:text-gray-400 px-4 py-2.5 whitespace-nowrap">
                Break down by
              </p>
              <div
                data-testid="dropdown-items"
                className="flex flex-col gap-y-0.5"
              >
                {BREAKDOWN_MODE_OPTIONS.map(({ value, label }) => (
                  <button
                    key={value}
                    onClick={() => {
                      onSelect(value)
                      close()
                    }}
                    data-selected={value === breakdownMode}
                    className={classNames(
                      popover.items.classNames.navigationLink,
                      popover.items.classNames.selectedOption,
                      popover.items.classNames.hoverLink
                    )}
                  >
                    {label}
                    <SelectedCheckmark selected={value === breakdownMode} />
                  </button>
                ))}
              </div>
            </Popover.Panel>
          </Transition>
        </>
      )}
    </Popover>
  )
}

function PathDimensionCell(props: DimensionCellWithBarProps) {
  const site = useSiteContext()
  const path = props.row.dimensions[0]
  const externalUrl = externalLinkForPage(site, path)

  return (
    <DimensionCellWithBar
      getFilterInfo={defaultGetFilterInfo}
      text={trimURL(path, MAX_DIMENSION_LENGTH)}
      barClassName={BAR_COLOR}
      externalLink={
        externalUrl && (
          <IndexExternalLink href={externalUrl} isActive={props.isActive} />
        )
      }
      {...props}
    />
  )
}

function makeHostnameDimensionCell(pageFilterKey: string) {
  const getFilterInfo: GetFilterInfo = (_dim, row) => ({
    prefix: 'hostname',
    filter: ['is', 'hostname', [row.dimensions[0]]] as Filter,
    extraFilters: [
      {
        prefix: pageFilterKey,
        filter: ['is', pageFilterKey, [row.dimensions[1]]] as Filter
      }
    ]
  })
  return function HostnameDimensionCell(props: DimensionCellWithBarProps) {
    const site = useSiteContext()
    const hostname = props.row.dimensions[0]
    const path = props.row.dimensions[1]
    const externalUrl = externalLinkForPage(site, path, hostname)

    const displayValue = trimURL(
      `https://${hostname}${path}`,
      MAX_DIMENSION_LENGTH + 8
    ).replace(/^https:\/\//, '')

    return (
      <DimensionCellWithBar
        getFilterInfo={getFilterInfo}
        text={displayValue}
        barClassName={BAR_COLOR}
        externalLink={
          externalUrl && (
            <IndexExternalLink href={externalUrl} isActive={props.isActive} />
          )
        }
        {...props}
      />
    )
  }
}

const HOSTNAME_DIMENSION_CELLS: Record<
  TabKey,
  (props: DimensionCellWithBarProps) => React.ReactNode
> = {
  [BreakdownReportKey.pages]: makeHostnameDimensionCell('page'),
  [BreakdownReportKey.entryPages]: makeHostnameDimensionCell('entry_page'),
  [BreakdownReportKey.exitPages]: makeHostnameDimensionCell('exit_page')
}

const initTab = (storedTab: string): TabKey => {
  switch (storedTab) {
    case LegacyTabKey.entryPages:
    case BreakdownReportKey.entryPages:
      return BreakdownReportKey.entryPages
    case LegacyTabKey.exitPages:
    case BreakdownReportKey.exitPages:
      return BreakdownReportKey.exitPages
    case BreakdownReportKey.pages:
    default:
      return BreakdownReportKey.pages
  }
}

enum LegacyTabKey {
  entryPages = 'entry-pages',
  exitPages = 'exit-pages'
}
