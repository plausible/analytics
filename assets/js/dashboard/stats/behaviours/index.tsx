import React, {
  ComponentType,
  Dispatch,
  ReactNode,
  SetStateAction,
  useState,
  useEffect,
  useCallback
} from 'react'
import * as storage from '../../util/storage'
import ImportedWarningBubble, {
  FunnelsApiImportedWarningBubble
} from '../imported-warning-bubble'
import Properties from './props'
import { FeatureSetupNotice } from '../../components/feature-setup-notice'
import {
  ExplorationPreviewMock,
  FunnelsPreviewMock,
  PropertiesPreviewMock
} from '../../components/feature-preview-mocks'
import {
  hasConversionGoalFilter,
  getGoalFilter,
  FILTER_OPERATIONS
} from '../../util/filters'
import { PlausibleSite, useSiteContext } from '../../site-context'
import { useDashboardStateContext } from '../../dashboard-state-context'
import { useUserContext } from '../../user-context'
import { DropdownTabButton, TabButton, TabWrapper } from '../../components/tabs'
import { ReportLayout } from '../reports/report-layout'
import { ReportHeader } from '../reports/report-header'
import MoreLink from '../more-link'
import { MoreLinkState } from '../more-link-state'
import { Pill } from '../../components/pill'
import * as api from '../../api'
import * as url from '../../util/url'
import { conversionsRoute, customPropsRoute } from '../../router'
import {
  Mode,
  getFirstPreferenceFromEnabledModes,
  ModesContextProvider,
  useModesContext
} from './modes-context'
import { SpecialGoalPropBreakdown } from './special-goal-prop-breakdown'
import Conversions from './conversions'
import { getSpecialGoal, isSpecialGoal } from '../../util/goals'
import { DashboardState, Filter } from '../../dashboard-state'
import { QueryApiResponse } from '../../api'
import { DEFAULT_METRIC_COLUMN_WIDTH } from '../reports/index-breakdown'
import { Metric } from '../metrics'

export const BEHAVIOURS_BAR_COLOR = 'bg-red-50 group-hover/row:bg-red-100'
export const BEHAVIOURS_METRIC_COLUMN_WIDTH = `${DEFAULT_METRIC_COLUMN_WIDTH} md:w-22 md:min-w-22`
export const BEHAVIOURS_METRICS_HIDDEN_ON_MOBILE: Metric[] = [
  'events',
  'total_revenue',
  'average_revenue'
]

/*global BUILD_EXTRA*/
/*global require*/
function maybeRequireFunnels(): {
  default: ComponentType<{ funnelName: string }> | null
} {
  if (BUILD_EXTRA) {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    return require('../../extra/funnel')
  } else {
    return { default: null }
  }
}

function maybeRequireExploration(): { default: ComponentType | null } {
  if (BUILD_EXTRA) {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    return require('../../extra/exploration')
  } else {
    return { default: null }
  }
}

const Funnel = maybeRequireFunnels().default
const FunnelExploration = maybeRequireExploration().default

function singleGoalFilterApplied(dashboardState: DashboardState): boolean {
  const goalFilter = getGoalFilter(dashboardState)
  if (goalFilter) {
    const [operation, _filterKey, clauses] = goalFilter as Filter
    return operation === FILTER_OPERATIONS.is && clauses.length === 1
  } else {
    return false
  }
}

const STORAGE_KEYS = {
  getForTab: ({ site }: { site: PlausibleSite }): string =>
    storage.getDomainScopedStorageKey('behavioursTab', site.domain),
  getForFunnel: ({ site }: { site: PlausibleSite }): string =>
    storage.getDomainScopedStorageKey('behavioursTabFunnel', site.domain),
  getForPropKey: ({ site }: { site: PlausibleSite }): string =>
    storage.getDomainScopedStorageKey('prop_key', site.domain),
  getForPropKeyForGoal: ({
    goalName,
    site
  }: {
    goalName: string
    site: PlausibleSite
  }): string =>
    storage.getDomainScopedStorageKey(`${goalName}__prop_key)`, site.domain)
}

function getPropKeyFromStorage({
  site,
  dashboardState
}: {
  site: PlausibleSite
  dashboardState: DashboardState
}): string | null {
  if (singleGoalFilterApplied(dashboardState)) {
    const goalFilter = getGoalFilter(dashboardState) as Filter
    const [_operation, _dimension, [goalName]] = goalFilter
    const storedForGoal = storage.getItem(
      STORAGE_KEYS.getForPropKeyForGoal({
        goalName: String(goalName),
        site
      })
    )
    if (storedForGoal) {
      return storedForGoal
    }
  }

  return storage.getItem(STORAGE_KEYS.getForPropKey({ site }))
}

function storePropKey({
  site,
  propKey,
  dashboardState
}: {
  site: PlausibleSite
  propKey: string
  dashboardState: DashboardState
}): void {
  if (singleGoalFilterApplied(dashboardState)) {
    const goalFilter = getGoalFilter(dashboardState) as Filter
    const [_operation, _dimension, [goalName]] = goalFilter
    storage.setItem(
      STORAGE_KEYS.getForPropKeyForGoal({ goalName: String(goalName), site }),
      propKey
    )
  } else {
    storage.setItem(STORAGE_KEYS.getForPropKey({ site }), propKey)
  }
}

function getDefaultSelectedFunnel({
  site
}: {
  site: PlausibleSite
}): string | undefined {
  const stored = storage.getItem(STORAGE_KEYS.getForFunnel({ site }))
  const storedExists = stored && site.funnels.some((f) => f.name === stored)

  if (storedExists) {
    return stored as string
  } else if (site.funnels.length > 0) {
    const firstAvailable = site.funnels[0].name
    storage.setItem(STORAGE_KEYS.getForFunnel({ site }), firstAvailable)
    return firstAvailable
  }
  return undefined
}

type BehavioursProps = {
  importedDataInView?: boolean
  setMode: Dispatch<SetStateAction<Mode | null>>
  mode: Mode
}

function Behaviours({
  importedDataInView,
  setMode,
  mode
}: BehavioursProps): ReactNode {
  const { dashboardState } = useDashboardStateContext()
  const goalFilter = getGoalFilter(dashboardState)
  const specialGoal = goalFilter ? getSpecialGoal(goalFilter) : null
  const site = useSiteContext()
  const user = useUserContext()
  const { enabledModes, disableMode } = useModesContext()
  const adminAccess = ['owner', 'admin', 'editor', 'super_admin'].includes(
    user.role
  )

  const [selectedFunnel, setSelectedFunnel] = useState<string | undefined>(
    getDefaultSelectedFunnel({ site })
  )
  const initialSelectedPropKey =
    getPropKeyFromStorage({ site, dashboardState }) || null
  const [selectedPropKey, setSelectedPropKey] = useState<string | null>(
    initialSelectedPropKey
  )
  const [propertyKeys, setPropertyKeys] = useState<string[]>(
    selectedPropKey !== null ? [selectedPropKey] : []
  )

  const [showingPropsForGoalFilter, setShowingPropsForGoalFilter] =
    useState(false)

  const [currentQueryApiResponse, setCurrentQueryApiResponse] =
    useState<QueryApiResponse | null>(null)

  const moreLinkState = currentQueryApiResponse
    ? currentQueryApiResponse.results.length > 0
      ? MoreLinkState.READY
      : MoreLinkState.HIDDEN
    : MoreLinkState.LOADING

  const onGoalFilterClick = useCallback(
    (goalName: string) => {
      const isSpecialGoalClick = isSpecialGoal(goalName)

      if (
        !isSpecialGoalClick &&
        enabledModes.includes(Mode.PROPS) &&
        site.hasProps
      ) {
        setShowingPropsForGoalFilter(true)
        setMode(Mode.PROPS)
      }
    },
    [enabledModes, setMode, site.hasProps]
  )

  useEffect(() => {
    const justRemovedGoalFilter = !hasConversionGoalFilter(dashboardState)
    if (
      mode === Mode.PROPS &&
      justRemovedGoalFilter &&
      showingPropsForGoalFilter
    ) {
      setShowingPropsForGoalFilter(false)
      setMode(Mode.CONVERSIONS)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [hasConversionGoalFilter(dashboardState)])

  useEffect(() => {
    if ([Mode.FUNNELS, Mode.EXPLORATION].includes(mode)) {
      setCurrentQueryApiResponse(null)
    }
  }, [dashboardState, mode])

  function setFunnelFactory(selectedFunnelName: string): () => void {
    return () => {
      storage.setItem(STORAGE_KEYS.getForTab({ site }), Mode.FUNNELS)
      storage.setItem(STORAGE_KEYS.getForFunnel({ site }), selectedFunnelName)
      setMode(Mode.FUNNELS)
      setSelectedFunnel(selectedFunnelName)
    }
  }

  function setPropKeyFactory(selectedPropKeyName: string): () => void {
    return () => {
      storage.setItem(STORAGE_KEYS.getForTab({ site }), Mode.PROPS)
      storePropKey({ site, propKey: selectedPropKeyName, dashboardState })
      setMode(Mode.PROPS)
      setSelectedPropKey(selectedPropKeyName)
    }
  }

  useEffect(() => {
    // Fetch property keys when PROPS mode is enabled (not just when active)
    // This ensures the dropdown appears immediately on page refresh
    if (
      enabledModes.includes(Mode.PROPS) &&
      site.hasProps &&
      site.propsAvailable
    ) {
      api
        .get(url.apiPath(site, '/suggestions/prop_key'), dashboardState, {
          q: ''
        })
        .then((propKeys: Array<{ value: string }>) => {
          const propKeyValues = propKeys.map((entry) => entry.value)
          setPropertyKeys(propKeyValues)
          if (propKeyValues.length > 0) {
            const stored = getPropKeyFromStorage({ site, dashboardState })
            const storedExists = stored && propKeyValues.includes(stored)

            if (storedExists) {
              setSelectedPropKey(stored)
            } else {
              const firstAvailable = propKeyValues[0]
              setSelectedPropKey(firstAvailable)
              storePropKey({ site, propKey: firstAvailable, dashboardState })
            }
          } else {
            setSelectedPropKey(null)
          }
        })
        .catch((error: unknown) => {
          console.error('Failed to fetch property keys:', error)
          setPropertyKeys([])
          setSelectedPropKey(null)
        })
    } else {
      // Clear property keys when PROPS is not available
      setPropertyKeys([])
      setSelectedPropKey(null)
    }
  }, [site, dashboardState, enabledModes])

  function setTabFactory(tab: Mode): () => void {
    return () => {
      storage.setItem(STORAGE_KEYS.getForTab({ site }), tab)
      setMode(tab)
    }
  }

  function renderConversions(): ReactNode {
    if (site.hasGoals) {
      if (specialGoal) {
        return (
          <SpecialGoalPropBreakdown
            prop={specialGoal.prop}
            onDataReady={setCurrentQueryApiResponse}
          />
        )
      } else {
        return (
          <Conversions
            onGoalFilterClick={onGoalFilterClick}
            onDataReady={setCurrentQueryApiResponse}
          />
        )
      }
    } else if (adminAccess) {
      return (
        <FeatureSetupNotice
          feature={Mode.CONVERSIONS}
          title={'Measure how often visitors complete specific actions'}
          info={
            'Goals allow you to track registrations, button clicks, form completions, external link clicks, file downloads, 404 error pages and more.'
          }
          callToAction={{
            action: 'Set up goals',
            link: `/${encodeURIComponent(site.domain)}/settings/goals`
          }}
          onHideAction={() => disableMode(Mode.CONVERSIONS)}
        />
      )
    } else {
      return noDataYet()
    }
  }

  function renderExploration(): ReactNode {
    if (FunnelExploration === null) {
      return featureUnavailable()
    }

    if (site.explorationAvailable) {
      return <FunnelExploration />
    }

    const callToAction = { action: 'Upgrade', link: '/billing/choose-plan' }

    return (
      <FeatureSetupNotice
        feature={Mode.EXPLORATION}
        title={'Explore user journeys'}
        info={
          'See how visitors move between pages and events to understand browsing behavior.'
        }
        callToAction={callToAction}
        secondaryCallToAction={{
          action: 'Learn more',
          link: 'https://plausible.io/docs/user-journeys'
        }}
        onHideAction={null}
        previewMock={<ExplorationPreviewMock />}
      />
    )
  }

  function renderFunnels(): ReactNode {
    if (Funnel === null) {
      return featureUnavailable()
    } else if (Funnel && selectedFunnel && site.funnelsAvailable) {
      return <Funnel funnelName={selectedFunnel} />
    } else if (Funnel && adminAccess) {
      let callToAction

      if (site.funnelsAvailable) {
        callToAction = {
          action: 'Set up funnels',
          link: `/${encodeURIComponent(site.domain)}/settings/funnels`
        }
      } else {
        callToAction = { action: 'Upgrade', link: '/billing/choose-plan' }
      }

      return (
        <FeatureSetupNotice
          feature={Mode.FUNNELS}
          title={'Analyze conversion funnels'}
          info={
            'Measure conversion rates between each step and identify where visitors drop off.'
          }
          callToAction={callToAction}
          onHideAction={() => disableMode(Mode.FUNNELS)}
          previewMock={
            !site.funnelsAvailable ? <FunnelsPreviewMock /> : undefined
          }
        />
      )
    } else {
      return noDataYet()
    }
  }

  function renderProps(): ReactNode {
    if (site.hasProps && site.propsAvailable) {
      return (
        <Properties
          propKey={selectedPropKey}
          onDataReady={setCurrentQueryApiResponse}
        />
      )
    } else if (adminAccess) {
      let callToAction

      if (site.propsAvailable) {
        callToAction = {
          action: 'Set up props',
          link: `/${encodeURIComponent(site.domain)}/settings/properties`
        }
      } else {
        callToAction = { action: 'Upgrade', link: '/billing/choose-plan' }
      }

      return (
        <FeatureSetupNotice
          feature={Mode.PROPS}
          title={'Attach your own data to the stats'}
          info={
            'Create custom metrics and analyze data specific to your business.'
          }
          callToAction={callToAction}
          onHideAction={() => disableMode(Mode.PROPS)}
          previewMock={
            !site.propsAvailable ? <PropertiesPreviewMock /> : undefined
          }
        />
      )
    } else {
      return noDataYet()
    }
  }

  function noDataYet(): ReactNode {
    return (
      <div className="flex-1 flex items-center justify-center font-medium text-gray-500 dark:text-gray-400">
        No data yet
      </div>
    )
  }

  function featureUnavailable(): ReactNode {
    return (
      <div className="flex-1 flex flex-col items-center justify-center font-medium text-gray-500 dark:text-gray-400">
        <span>This report is available in Plausible Cloud</span>
        <a
          className="flex items-center gap-x-1.5 mt-4 button px-2 sm:px-4"
          href="https://plausible.io"
        >
          Learn more
        </a>
      </div>
    )
  }

  function renderContent(): ReactNode {
    switch (mode) {
      case Mode.CONVERSIONS:
        return renderConversions()
      case Mode.PROPS:
        return renderProps()
      case Mode.FUNNELS:
        return renderFunnels()
      case Mode.EXPLORATION:
        return renderExploration()
    }
  }

  function getMoreLinkProps(): {
    path: string
    params?: Record<string, string>
    search: (search: string) => string
  } | null {
    switch (mode) {
      case Mode.CONVERSIONS:
        return specialGoal
          ? {
              path: customPropsRoute.path,
              params: { propKey: url.maybeEncodeRouteParam(specialGoal.prop) },
              search: (search: string) => search
            }
          : {
              path: conversionsRoute.path,
              search: (search: string) => search
            }
      case Mode.PROPS:
        if (!selectedPropKey) {
          return null
        }
        return {
          path: customPropsRoute.path,
          params: { propKey: url.maybeEncodeRouteParam(selectedPropKey) },
          search: (search: string) => search
        }
      default:
        return null
    }
  }

  function isEnabled(checkMode: Mode): boolean {
    return enabledModes.includes(checkMode)
  }

  function isRealtime(): boolean {
    return dashboardState.period === 'realtime'
  }

  if (!mode) {
    return null
  }

  const moreLinkProps = getMoreLinkProps()

  return (
    <ReportLayout testId="report-behaviours" className="col-span-full">
      <ReportHeader>
        <div className="flex gap-x-2">
          <TabWrapper>
            {isEnabled(Mode.CONVERSIONS) &&
              (specialGoal ? (
                <TabButton
                  active={mode === Mode.CONVERSIONS}
                  onClick={setTabFactory(Mode.CONVERSIONS)}
                >
                  {specialGoal.title}
                </TabButton>
              ) : (
                <TabButton
                  active={mode === Mode.CONVERSIONS}
                  onClick={setTabFactory(Mode.CONVERSIONS)}
                >
                  Goals
                </TabButton>
              ))}
            {isEnabled(Mode.PROPS) &&
            !!propertyKeys.length &&
            site.propsAvailable ? (
              <DropdownTabButton
                className="md:relative"
                transitionClassName="md:left-auto md:w-88 md:origin-top-right"
                active={mode === Mode.PROPS}
                options={propertyKeys.map((key) => ({
                  label: key,
                  onClick: setPropKeyFactory(key),
                  selected: selectedPropKey === key
                }))}
                searchable={true}
              >
                Properties
              </DropdownTabButton>
            ) : (
              <TabButton
                active={mode === Mode.PROPS}
                onClick={setTabFactory(Mode.PROPS)}
              >
                Properties
              </TabButton>
            )}
            {!site.isConsolidatedView &&
              isEnabled(Mode.FUNNELS) &&
              Funnel &&
              (site.funnels.length > 0 && site.funnelsAvailable ? (
                <DropdownTabButton
                  className="md:relative"
                  transitionClassName="md:left-auto md:w-88 md:origin-top-right"
                  active={mode === Mode.FUNNELS}
                  options={site.funnels.map(({ name }) => ({
                    label: name,
                    onClick: setFunnelFactory(name),
                    selected: mode === Mode.FUNNELS && selectedFunnel === name
                  }))}
                  searchable={true}
                >
                  Funnels
                </DropdownTabButton>
              ) : (
                <TabButton
                  active={mode === Mode.FUNNELS}
                  onClick={setTabFactory(Mode.FUNNELS)}
                >
                  Funnels
                </TabButton>
              ))}
            {!site.isConsolidatedView && isEnabled(Mode.EXPLORATION) && (
              <TabButton
                active={mode === Mode.EXPLORATION}
                onClick={setTabFactory(Mode.EXPLORATION)}
              >
                Explore
              </TabButton>
            )}
          </TabWrapper>
          {isRealtime() && mode === Mode.CONVERSIONS && (
            <Pill className="-mt-1">last 30min</Pill>
          )}
          {[Mode.CONVERSIONS, Mode.PROPS].includes(mode) ? (
            <ImportedWarningBubble
              queryApiResponse={currentQueryApiResponse}
              message={
                mode === Mode.PROPS
                  ? 'Imported data is unavailable in this view'
                  : undefined
              }
            />
          ) : (
            <FunnelsApiImportedWarningBubble
              importedDataInView={importedDataInView}
            />
          )}
        </div>
        {moreLinkProps !== null && (
          <MoreLink state={moreLinkState} linkProps={moreLinkProps} />
        )}
      </ReportHeader>
      {renderContent()}
    </ReportLayout>
  )
}

function BehavioursOuter({
  importedDataInView
}: {
  importedDataInView?: boolean
}): ReactNode {
  const site = useSiteContext()
  const { enabledModes } = useModesContext()
  const [mode, setMode] = useState<Mode | null>(null)

  useEffect(() => {
    const storedMode = storage.getItem(STORAGE_KEYS.getForTab({ site }))
    // updates current mode when available modes change (if needed), loads user's stored mode
    setMode((currentMode) =>
      getFirstPreferenceFromEnabledModes(
        [currentMode, storedMode] as Mode[],
        enabledModes
      )
    )
  }, [enabledModes, site])

  return enabledModes.length && mode ? (
    <Behaviours
      importedDataInView={importedDataInView}
      mode={mode}
      setMode={setMode}
    />
  ) : null
}

export default function BehavioursWrapped({
  importedDataInView
}: {
  importedDataInView?: boolean
}): ReactNode {
  return (
    <ModesContextProvider>
      <BehavioursOuter importedDataInView={importedDataInView} />
    </ModesContextProvider>
  )
}
