import React, { useState, useEffect, useCallback } from 'react'
import * as storage from '../../util/storage'
import ImportedQueryUnsupportedWarning from '../imported-query-unsupported-warning'
import GoalConversions, {
  specialTitleWhenGoalFilter,
  SPECIAL_GOALS
} from './goal-conversions'
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

export const CONVERSIONS = 'conversions'
export const PROPS = 'props'
export const FUNNELS = 'funnels'

export const sectionTitles = {
  [CONVERSIONS]: 'Goal conversions',
  [PROPS]: 'Custom properties',
  [FUNNELS]: 'Funnels'
}

export default function Behaviours({ importedDataInView }) {
  const { query } = useQueryContext()
  const site = useSiteContext()
  const user = useUserContext()
  const adminAccess = ['owner', 'admin', 'editor', 'super_admin'].includes(
    user.role
  )
  const tabKey = storage.getDomainScopedStorageKey('behavioursTab', site.domain)
  const funnelKey = storage.getDomainScopedStorageKey(
    'behavioursTabFunnel',
    site.domain
  )
  const propKeyStorageName = `prop_key__${site.domain}`
  const propKeyStorageNameForGoal = () => {
    const [_operation, _filterKey, [goal]] = getGoalFilter(query)
    return `${goal}__prop_key__${site.domain}`
  }
  const [enabledModes, setEnabledModes] = useState(getEnabledModes())
  const [mode, setMode] = useState(defaultMode())
  const [loading, setLoading] = useState(true)

  const [selectedFunnel, setSelectedFunnel] = useState(defaultSelectedFunnel())
  const [propertyKeys, setPropertyKeys] = useState([])
  // Initialize selectedPropKey from storage immediately to show dropdown on page refresh
  const [selectedPropKey, setSelectedPropKey] = useState(() => {
    // Inline storage logic to avoid dependency on functions defined later
    const goalFilter = getGoalFilter(query)
    let stored = null

    if (goalFilter) {
      const [operation, _filterKey, clauses] = goalFilter
      if (operation === FILTER_OPERATIONS.is && clauses.length === 1) {
        const [goal] = clauses
        const goalStorageKey = `${goal}__prop_key__${site.domain}`
        stored = storage.getItem(goalStorageKey)
      }
    }

    if (!stored) {
      stored = storage.getItem(propKeyStorageName)
    }

    return stored || null
  })

  // Optimistically add selectedPropKey to propertyKeys on mount so dropdown shows immediately
  useEffect(() => {
    if (selectedPropKey && propertyKeys.length === 0) {
      setPropertyKeys([selectedPropKey])
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const [showingPropsForGoalFilter, setShowingPropsForGoalFilter] =
    useState(false)

  const [skipImportedReason, setSkipImportedReason] = useState(null)
  const [moreLinkState, setMoreLinkState] = useState(MoreLinkState.LOADING)

  const onGoalFilterClick = useCallback((e) => {
    const goalName = e.target.innerHTML
    const isSpecialGoal = Object.keys(SPECIAL_GOALS).includes(goalName)
    const isPageviewGoal = goalName.startsWith('Visit ')

    if (
      !isSpecialGoal &&
      !isPageviewGoal &&
      enabledModes.includes(PROPS) &&
      site.hasProps
    ) {
      setShowingPropsForGoalFilter(true)
      setMode(PROPS)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    const justRemovedGoalFilter = !hasConversionGoalFilter(query)
    if (mode === PROPS && justRemovedGoalFilter && showingPropsForGoalFilter) {
      setShowingPropsForGoalFilter(false)
      setMode(CONVERSIONS)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [hasConversionGoalFilter(query)])

  useEffect(() => {
    setMode(defaultMode())
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [enabledModes])

  useEffect(() => setLoading(true), [query, mode])
  useEffect(() => {
    if (mode === PROPS && !selectedPropKey) {
      setMoreLinkState(MoreLinkState.HIDDEN)
    } else {
      setMoreLinkState(MoreLinkState.LOADING)
    }
  }, [query, mode, selectedPropKey])

  function disableMode(mode) {
    setEnabledModes(
      enabledModes.filter((m) => {
        return m !== mode
      })
    )
  }

  function setFunnelFactory(selectedFunnelName) {
    return () => {
      storage.setItem(tabKey, FUNNELS)
      storage.setItem(funnelKey, selectedFunnelName)
      setMode(FUNNELS)
      setSelectedFunnel(selectedFunnelName)
    }
  }

  function setPropKeyFactory(selectedPropKeyName) {
    return () => {
      storage.setItem(tabKey, PROPS)
      const storageName = singleGoalFilterApplied()
        ? propKeyStorageNameForGoal()
        : propKeyStorageName
      storage.setItem(storageName, selectedPropKeyName)
      setMode(PROPS)
      setSelectedPropKey(selectedPropKeyName)
    }
  }

  function singleGoalFilterApplied() {
    const goalFilter = getGoalFilter(query)
    if (goalFilter) {
      const [operation, _filterKey, clauses] = goalFilter
      return operation === FILTER_OPERATIONS.is && clauses.length === 1
    } else {
      return false
    }
  }

  function getPropKeyFromStorage() {
    if (singleGoalFilterApplied()) {
      const storedForGoal = storage.getItem(propKeyStorageNameForGoal())
      if (storedForGoal) {
        return storedForGoal
      }
    }

    return storage.getItem(propKeyStorageName)
  }

  useEffect(() => {
    // Fetch property keys when PROPS mode is enabled (not just when active)
    // This ensures the dropdown appears immediately on page refresh
    if (enabledModes.includes(PROPS) && site.hasProps && site.propsAvailable) {
      api
        .get(url.apiPath(site, '/suggestions/prop_key'), query, {
          q: ''
        })
        .then((propKeys) => {
          const propKeyValues = propKeys.map((entry) => entry.value)
          setPropertyKeys(propKeyValues)
          if (propKeyValues.length > 0) {
            const stored = getPropKeyFromStorage()
            const storedExists = stored && propKeyValues.includes(stored)

            if (storedExists) {
              setSelectedPropKey(stored)
            } else {
              const firstAvailable = propKeyValues[0]
              setSelectedPropKey(firstAvailable)
              const storageName = singleGoalFilterApplied()
                ? propKeyStorageNameForGoal()
                : propKeyStorageName
              storage.setItem(storageName, firstAvailable)
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
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query, enabledModes, site.hasProps, site.propsAvailable])

  function defaultSelectedFunnel() {
    const stored = storage.getItem(funnelKey)
    const storedExists = stored && site.funnels.some((f) => f.name === stored)

    if (storedExists) {
      return stored
    } else if (site.funnels.length > 0) {
      const firstAvailable = site.funnels[0].name

      storage.setItem(funnelKey, firstAvailable)
      return firstAvailable
    }
  }

  function setTabFactory(tab) {
    return () => {
      storage.setItem(tabKey, tab)
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
      return (
        <GoalConversions
          onGoalFilterClick={onGoalFilterClick}
          afterFetchData={afterFetchData}
        />
      )
    } else if (adminAccess) {
      return (
        <FeatureSetupNotice
          feature={CONVERSIONS}
          title={'Measure how often visitors complete specific actions'}
          info={
            'Goals allow you to track registrations, button clicks, form completions, external link clicks, file downloads, 404 error pages and more.'
          }
          callToAction={{
            action: 'Set up goals',
            link: `/${encodeURIComponent(site.domain)}/settings/goals`
          }}
          onHideAction={onHideAction(CONVERSIONS)}
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
          feature={FUNNELS}
          title={'Follow the visitor journey from entry to conversion'}
          info={
            'Funnels allow you to analyze the user flow through your website, uncover possible issues, optimize your site and increase the conversion rate.'
          }
          callToAction={callToAction}
          onHideAction={onHideAction(FUNNELS)}
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
          feature={PROPS}
          title={'Send custom data to create your own metrics'}
          info={
            "You can attach custom properties when sending a pageview or event. This allows you to create custom metrics and analyze stats we don't track automatically."
          }
          callToAction={callToAction}
          onHideAction={onHideAction(PROPS)}
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

  function onHideAction(mode) {
    return () => {
      disableMode(mode)
    }
  }

  function renderContent() {
    switch (mode) {
      case CONVERSIONS:
        return renderConversions()
      case PROPS:
        return renderProps()
      case FUNNELS:
        return renderFunnels()
    }
  }

  function defaultMode() {
    if (enabledModes.length === 0) {
      return null
    }

    const storedMode = storage.getItem(tabKey)
    if (storedMode && enabledModes.includes(storedMode)) {
      return storedMode
    }

    if (enabledModes.includes(CONVERSIONS)) {
      return CONVERSIONS
    }
    if (enabledModes.includes(PROPS)) {
      return PROPS
    }
    return FUNNELS
  }

  function moreLinkProps() {
    switch (mode) {
      case CONVERSIONS:
        return {
          path: conversionsRoute.path,
          search: (search) => search
        }
      case PROPS:
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

  function getEnabledModes() {
    let enabledModes = []

    for (const feature of Object.keys(sectionTitles)) {
      const isOptedOut = site[feature + 'OptedOut']
      const isAvailable = site[feature + 'Available'] !== false

      // If the feature is not supported by the site owner's subscription,
      // it only makes sense to display the feature tab to the owner itself
      // as only they can upgrade to make the feature available.
      const callToActionIsMissing = !isAvailable && user.role !== 'owner'

      if (!isOptedOut && !callToActionIsMissing) {
        enabledModes.push(feature)
      }
    }

    return enabledModes
  }

  function isEnabled(mode) {
    return enabledModes.includes(mode)
  }

  function isRealtime() {
    return query.period === 'realtime'
  }

  function renderImportedQueryUnsupportedWarning() {
    if (mode === CONVERSIONS) {
      return (
        <ImportedQueryUnsupportedWarning
          loading={loading}
          skipImportedReason={skipImportedReason}
        />
      )
    } else if (mode === PROPS) {
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
            {isEnabled(CONVERSIONS) && (
              <TabButton
                active={mode === CONVERSIONS}
                onClick={setTabFactory(CONVERSIONS)}
              >
                {specialTitleWhenGoalFilter(query, 'Goals')}
              </TabButton>
            )}
            {isEnabled(PROPS) &&
              ((propertyKeys.length > 0 || selectedPropKey) &&
              site.propsAvailable ? (
                <DropdownTabButton
                  className="md:relative"
                  transitionClassName="md:left-auto md:w-88 md:origin-top-right"
                  active={mode === PROPS}
                  options={
                    propertyKeys.length > 0
                      ? propertyKeys.map((key) => ({
                          label: key,
                          onClick: setPropKeyFactory(key),
                          selected: mode === PROPS && selectedPropKey === key
                        }))
                      : selectedPropKey
                        ? [
                            {
                              label: selectedPropKey,
                              onClick: setPropKeyFactory(selectedPropKey),
                              selected: true
                            }
                          ]
                        : []
                  }
                  searchable={true}
                >
                  Properties
                </DropdownTabButton>
              ) : (
                <TabButton
                  active={mode === PROPS}
                  onClick={setTabFactory(PROPS)}
                >
                  Properties
                </TabButton>
              ))}
            {isEnabled(FUNNELS) &&
              Funnel &&
              (site.funnels.length > 0 && site.funnelsAvailable ? (
                <DropdownTabButton
                  className="md:relative"
                  transitionClassName="md:left-auto md:w-88 md:origin-top-right"
                  active={mode === FUNNELS}
                  options={site.funnels.map(({ name }) => ({
                    label: name,
                    onClick: setFunnelFactory(name),
                    selected: mode === FUNNELS && selectedFunnel === name
                  }))}
                  searchable={true}
                >
                  Funnels
                </DropdownTabButton>
              ) : (
                <TabButton
                  active={mode === FUNNELS}
                  onClick={setTabFactory(FUNNELS)}
                >
                  Funnels
                </TabButton>
              ))}
          </TabWrapper>
          {isRealtime() && <Pill className="-mt-1">last 30min</Pill>}
          {renderImportedQueryUnsupportedWarning()}
        </div>
        {mode !== FUNNELS && (
          <MoreLink state={moreLinkState} linkProps={moreLinkProps()} />
        )}
      </ReportHeader>
      {renderContent()}
    </ReportLayout>
  )
}
