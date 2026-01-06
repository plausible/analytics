import React, { useState, useEffect, useCallback } from 'react'
import * as storage from '../../util/storage'
import ImportedQueryUnsupportedWarning from '../imported-query-unsupported-warning'
import Properties from './props'
import { FeatureSetupNotice } from '../../components/notice'
import {
  hasConversionGoalFilter,
  getGoalFilter,
  FILTER_OPERATIONS
} from '../../util/filters'
import { useSiteContext } from '../../site-context'
import { useQueryContext } from '../../query-context'
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
import { getSpecialGoal, isPageViewGoal, isSpecialGoal } from '../../util/goals'

/*global BUILD_EXTRA*/
/*global require*/
function maybeRequire() {
  if (BUILD_EXTRA) {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    return require('../../extra/funnel')
  } else {
    return { default: null }
  }
}

const Funnel = maybeRequire().default

function singleGoalFilterApplied(query) {
  const goalFilter = getGoalFilter(query)
  if (goalFilter) {
    const [operation, _filterKey, clauses] = goalFilter
    return operation === FILTER_OPERATIONS.is && clauses.length === 1
  } else {
    return false
  }
}

const STORAGE_KEYS = {
  getForTab: ({ site }) =>
    storage.getDomainScopedStorageKey('behavioursTab', site.domain),
  getForFunnel: ({ site }) =>
    storage.getDomainScopedStorageKey('behavioursTabFunnel', site.domain),
  getForPropKey: ({ site }) =>
    storage.getDomainScopedStorageKey('prop_key', site.domain),
  getForPropKeyForGoal: ({ goalName, site }) => {
    return storage.getDomainScopedStorageKey(
      `${goalName}__prop_key)`,
      site.domain
    )
  }
}

function getPropKeyFromStorage({ site, query }) {
  if (singleGoalFilterApplied(query)) {
    const [_operation, _dimension, [goalName]] = getGoalFilter(query)
    const storedForGoal = storage.getItem(
      STORAGE_KEYS.getForPropKeyForGoal({ goalName, site })
    )
    if (storedForGoal) {
      return storedForGoal
    }
  }

  return storage.getItem(STORAGE_KEYS.getForPropKey({ site }))
}

function storePropKey({ site, propKey, query }) {
  if (singleGoalFilterApplied(query)) {
    const [_operation, _dimension, [goalName]] = getGoalFilter(query)
    storage.setItem(
      STORAGE_KEYS.getForPropKeyForGoal({ goalName, site }),
      propKey
    )
  } else {
    storage.setItem(STORAGE_KEYS.getForPropKey({ site }), propKey)
  }
}

function getDefaultSelectedFunnel({ site }) {
  const stored = storage.getItem(STORAGE_KEYS.getForFunnel({ site }))
  const storedExists = stored && site.funnels.some((f) => f.name === stored)

  if (storedExists) {
    return stored
  } else if (site.funnels.length > 0) {
    const firstAvailable = site.funnels[0].name
    storage.setItem(STORAGE_KEYS.getForFunnel({ site }), firstAvailable)
    return firstAvailable
  }
}

function Behaviours({ importedDataInView, setMode, mode }) {
  const { query } = useQueryContext()
  const goalFilter = getGoalFilter(query)
  const specialGoal = goalFilter ? getSpecialGoal(goalFilter) : null
  const site = useSiteContext()
  const user = useUserContext()
  const { enabledModes, disableMode } = useModesContext()
  const adminAccess = ['owner', 'admin', 'editor', 'super_admin'].includes(
    user.role
  )
  const [loading, setLoading] = useState(true)

  const [selectedFunnel, setSelectedFunnel] = useState(
    getDefaultSelectedFunnel({ site })
  )
  const initialSelectedPropKey = getPropKeyFromStorage({ site, query }) || null
  const [selectedPropKey, setSelectedPropKey] = useState(initialSelectedPropKey)
  const [propertyKeys, setPropertyKeys] = useState(
    selectedPropKey !== null ? [selectedPropKey] : []
  )

  const [showingPropsForGoalFilter, setShowingPropsForGoalFilter] =
    useState(false)

  const [skipImportedReason, setSkipImportedReason] = useState(null)
  const [moreLinkState, setMoreLinkState] = useState(MoreLinkState.LOADING)

  const onGoalFilterClick = useCallback(
    (e) => {
      const goalName = e.target.innerHTML
      const isSpecial = isSpecialGoal(goalName)
      const isPageview = isPageViewGoal(goalName)

      if (
        !isSpecial &&
        !isPageview &&
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
    const justRemovedGoalFilter = !hasConversionGoalFilter(query)
    if (
      mode === Mode.PROPS &&
      justRemovedGoalFilter &&
      showingPropsForGoalFilter
    ) {
      setShowingPropsForGoalFilter(false)
      setMode(Mode.CONVERSIONS)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [hasConversionGoalFilter(query)])

  useEffect(() => setLoading(true), [query, mode])
  useEffect(() => {
    if (mode === Mode.PROPS && !selectedPropKey) {
      setMoreLinkState(MoreLinkState.HIDDEN)
    } else {
      setMoreLinkState(MoreLinkState.LOADING)
    }
  }, [query, mode, selectedPropKey])

  function setFunnelFactory(selectedFunnelName) {
    return () => {
      storage.setItem(STORAGE_KEYS.getForTab({ site }), Mode.FUNNELS)
      storage.setItem(STORAGE_KEYS.getForFunnel({ site }), selectedFunnelName)
      setMode(Mode.FUNNELS)
      setSelectedFunnel(selectedFunnelName)
    }
  }

  function setPropKeyFactory(selectedPropKeyName) {
    return () => {
      storage.setItem(STORAGE_KEYS.getForTab({ site }), Mode.PROPS)
      storePropKey({ site, propKey: selectedPropKeyName, query })
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
        .get(url.apiPath(site, '/suggestions/prop_key'), query, {
          q: ''
        })
        .then((propKeys) => {
          const propKeyValues = propKeys.map((entry) => entry.value)
          setPropertyKeys(propKeyValues)
          if (propKeyValues.length > 0) {
            const stored = getPropKeyFromStorage({ site, query })
            const storedExists = stored && propKeyValues.includes(stored)

            if (storedExists) {
              setSelectedPropKey(stored)
            } else {
              const firstAvailable = propKeyValues[0]
              setSelectedPropKey(firstAvailable)
              storePropKey({ site, propKey: firstAvailable, query })
            }
          } else {
            setSelectedPropKey(null)
          }
        })
        .catch((error) => {
          console.error('Failed to fetch property keys:', error)
          setPropertyKeys([])
          setSelectedPropKey(null)
        })
    } else {
      // Clear property keys when PROPS is not available
      setPropertyKeys([])
      setSelectedPropKey(null)
    }
  }, [site, query, enabledModes])

  function setTabFactory(tab) {
    return () => {
      storage.setItem(STORAGE_KEYS.getForTab({ site }), tab)
      setMode(tab)
    }
  }

  function afterFetchData(apiResponse) {
    setLoading(false)
    setSkipImportedReason(apiResponse.skip_imported_reason)
    if (apiResponse.results && apiResponse.results.length > 0) {
      setMoreLinkState(MoreLinkState.READY)
    } else {
      setMoreLinkState(MoreLinkState.HIDDEN)
    }
  }

  function renderConversions() {
    if (site.hasGoals) {
      if (specialGoal) {
        return (
          <SpecialGoalPropBreakdown
            prop={specialGoal.prop}
            afterFetchData={afterFetchData}
          />
        )
      } else {
        return (
          <Conversions
            onGoalFilterClick={onGoalFilterClick}
            afterFetchData={afterFetchData}
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

  function renderFunnels() {
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
          title={'Follow the visitor journey from entry to conversion'}
          info={
            'Funnels allow you to analyze the user flow through your website, uncover possible issues, optimize your site and increase the conversion rate.'
          }
          callToAction={callToAction}
          onHideAction={() => disableMode(Mode.FUNNELS)}
        />
      )
    } else {
      return noDataYet()
    }
  }

  function renderProps() {
    if (site.hasProps && site.propsAvailable) {
      return (
        <Properties propKey={selectedPropKey} afterFetchData={afterFetchData} />
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
          title={'Send custom data to create your own metrics'}
          info={
            "You can attach custom properties when sending a pageview or event. This allows you to create custom metrics and analyze stats we don't track automatically."
          }
          callToAction={callToAction}
          onHideAction={() => disableMode(Mode.PROPS)}
        />
      )
    } else {
      return noDataYet()
    }
  }

  function noDataYet() {
    return (
      <div className="font-medium text-gray-500 dark:text-gray-400 py-12 text-center">
        No data yet
      </div>
    )
  }

  function featureUnavailable() {
    return (
      <div className="font-medium text-gray-500 dark:text-gray-400 py-12 text-center">
        This feature is unavailable
      </div>
    )
  }

  function renderContent() {
    switch (mode) {
      case Mode.CONVERSIONS:
        return renderConversions()
      case Mode.PROPS:
        return renderProps()
      case Mode.FUNNELS:
        return renderFunnels()
    }
  }

  function getMoreLinkProps() {
    switch (mode) {
      case Mode.CONVERSIONS:
        return specialGoal
          ? {
              path: customPropsRoute.path,
              params: { propKey: url.maybeEncodeRouteParam(specialGoal.prop) },
              search: (search) => search
            }
          : {
              path: conversionsRoute.path,
              search: (search) => search
            }
      case Mode.PROPS:
        if (!selectedPropKey) {
          return null
        }
        return {
          path: customPropsRoute.path,
          params: { propKey: url.maybeEncodeRouteParam(selectedPropKey) },
          search: (search) => search
        }
      default:
        return null
    }
  }

  function isEnabled(mode) {
    return enabledModes.includes(mode)
  }

  function isRealtime() {
    return query.period === 'realtime'
  }

  function renderImportedQueryUnsupportedWarning() {
    if (mode === Mode.CONVERSIONS) {
      return (
        <ImportedQueryUnsupportedWarning
          loading={loading}
          skipImportedReason={skipImportedReason}
        />
      )
    } else if (mode === Mode.PROPS) {
      return (
        <ImportedQueryUnsupportedWarning
          loading={loading}
          skipImportedReason={skipImportedReason}
          message="Imported data is unavailable in this view"
        />
      )
    } else {
      return (
        <ImportedQueryUnsupportedWarning
          altCondition={importedDataInView}
          message="Imported data is unavailable in this view"
        />
      )
    }
  }

  if (!mode) {
    return null
  }

  return (
    <ReportLayout className="col-span-full">
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
            {isEnabled(Mode.FUNNELS) &&
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
          </TabWrapper>
          {isRealtime() && <Pill className="-mt-1">last 30min</Pill>}
          {renderImportedQueryUnsupportedWarning()}
        </div>
        {mode !== Mode.FUNNELS && (
          <MoreLink state={moreLinkState} linkProps={getMoreLinkProps()} />
        )}
      </ReportHeader>
      {renderContent()}
    </ReportLayout>
  )
}

function BehavioursOuter({ importedDataInView }) {
  const site = useSiteContext()
  const { enabledModes } = useModesContext()
  const [mode, setMode] = useState(null)

  useEffect(() => {
    const storedMode = storage.getItem(STORAGE_KEYS.getForTab({ site }))
    // updates current mode when available modes change (if needed), loads user's stored mode
    setMode((currentMode) =>
      getFirstPreferenceFromEnabledModes(
        [currentMode, storedMode],
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

export default function BehavioursWrapped({ importedDataInView }) {
  return (
    <ModesContextProvider>
      <BehavioursOuter importedDataInView={importedDataInView} />
    </ModesContextProvider>
  )
}
