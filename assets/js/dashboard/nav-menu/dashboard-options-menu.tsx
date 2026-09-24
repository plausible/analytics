import React, { useEffect, useRef, useState } from 'react'
import { Popover, Transition } from '@headlessui/react'
import { EllipsisVerticalIcon } from '@heroicons/react/24/outline'
import { Toggle } from '../components/toggle'
import classNames from 'classnames'
import { popover, BlurMenuButtonOnEscape } from '../components/popover'
import { useGraphIntervalContext } from '../stats/graph/graph-interval-context'
import { useImportsIncludedContext } from '../stats/graph/imports-included-context'
import { useDashboardStateContext } from '../dashboard-state-context'
import { DashboardPeriod } from '../dashboard-time-periods'
import { IntervalPicker } from '../stats/graph/interval-picker'
import { AppNavigationLink } from '../navigation/use-app-navigate'
import { Notice } from '../components/notice'
import { isModifierPressed, isTyping, Keybind } from '../keybinding'
import { useMatch } from 'react-router-dom'
import { rootRoute } from '../router'
import { CsvExport, ExportStatus } from '../stats/csv-export/csv-export'

function ImportedSwitchItem({ disabled }: { disabled: boolean }) {
  const { dashboardState } = useDashboardStateContext()
  const importsSwitchedOn = dashboardState.with_imported

  return (
    <AppNavigationLink
      data-testid="import-switch"
      search={
        disabled
          ? (search) => search
          : (search) => ({ ...search, with_imported: !importsSwitchedOn })
      }
      className={classNames(
        popover.items.classNames.navigationLink,
        disabled
          ? 'cursor-not-allowed opacity-50'
          : popover.items.classNames.hoverLink
      )}
    >
      Include imported data
      <Toggle on={importsSwitchedOn} disabled={disabled} />
    </AppNavigationLink>
  )
}

function DashboardOptionsMenuItems() {
  const { dashboardState } = useDashboardStateContext()
  const { selectedInterval, onIntervalClick, availableIntervals } =
    useGraphIntervalContext()
  const imports = useImportsIncludedContext()
  const buttonRef = useRef<HTMLButtonElement>(null)
  const [exportStatus, setExportStatus] = useState<ExportStatus>(
    ExportStatus.idle
  )

  useEffect(() => {
    setExportStatus((prev) =>
      prev === ExportStatus.error ? ExportStatus.idle : prev
    )
  }, [dashboardState])

  const showIntervalSection = availableIntervals.length > 1

  const dashboardRouteMatch = useMatch(rootRoute.path)
  const n = availableIntervals.length

  return (
    <>
      {showIntervalSection && !!dashboardRouteMatch && (
        <Keybind
          targetRef="document"
          type="keydown"
          keyboardKey="i"
          handler={() => {
            const idx = availableIntervals.indexOf(selectedInterval)
            const i = idx >= 0 ? idx : 0
            onIntervalClick(availableIntervals[(i + 1) % n])
          }}
          shouldIgnoreWhen={[isModifierPressed, isTyping]}
        />
      )}
      <BlurMenuButtonOnEscape targetRef={buttonRef} />
      <Popover.Button
        ref={buttonRef}
        data-testid="dashboard-options-menu"
        className={classNames(
          popover.toggleButton.classNames.rounded,
          popover.toggleButton.classNames.ghost,
          'justify-center'
        )}
      >
        <EllipsisVerticalIcon className="-mx-px size-4.5" />
      </Popover.Button>
      <Transition
        as="div"
        {...popover.transition.props}
        className={classNames(popover.transition.classNames.right, 'mt-2')}
      >
        <Popover.Panel
          className={classNames(
            popover.panel.classNames.roundedSheet,
            'min-w-72'
          )}
        >
          {showIntervalSection && (
            <IntervalPicker
              selectedInterval={selectedInterval}
              onIntervalClick={onIntervalClick}
              options={availableIntervals}
            />
          )}
          <CsvExport
            exportStatus={exportStatus}
            setExportStatus={setExportStatus}
          />
          {imports.status === 'visible' && (
            <>
              <ImportedSwitchItem disabled={imports.disabled} />
              {imports.disabled ? (
                <Notice
                  className="m-1"
                  title="Imported data unavailable with current filters."
                />
              ) : (
                imports.intervalUnsupportedNotice && (
                  <Notice
                    className="m-1"
                    {...imports.intervalUnsupportedNotice}
                  />
                )
              )}
            </>
          )}
        </Popover.Panel>
      </Transition>
    </>
  )
}

export function DashboardOptionsMenu() {
  const imports = useImportsIncludedContext()
  const { dashboardState } = useDashboardStateContext()
  const isRealtime = dashboardState.period === DashboardPeriod.realtime

  if (isRealtime) {
    return null
  }

  if (imports.status === 'loading') {
    return (
      <button
        disabled
        className={classNames(
          popover.toggleButton.classNames.rounded,
          popover.toggleButton.classNames.ghost,
          'justify-center'
        )}
      >
        <EllipsisVerticalIcon className="-mx-px size-4.5" />
      </button>
    )
  }

  return (
    <Popover className="md:relative">
      {() => <DashboardOptionsMenuItems />}
    </Popover>
  )
}
