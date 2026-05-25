import React from 'react'
import classNames from 'classnames'
import { MODES } from '../stats/behaviours/modes-context'
import * as api from '../api'
import { useSiteContext } from '../site-context'
import { Pill } from './pill'
import { DiamondIcon } from './icons'
import { buttonClassName } from './button'

function BusinessPill() {
  return (
    <Pill color="yellow">
      <DiamondIcon className="size-3.5 [&_path]:stroke-2" />
      Business
    </Pill>
  )
}

export function FeatureSetupNotice({
  feature,
  title,
  info,
  callToAction,
  secondaryCallToAction,
  onHideAction,
  previewMock
}: {
  feature: keyof typeof MODES
  title: React.ReactNode
  info: React.ReactNode
  callToAction: { link: string; action: string }
  secondaryCallToAction?: { link: string; action: string }
  onHideAction: (() => void) | null
  previewMock?: React.ReactNode
}) {
  const site = useSiteContext()
  const sectionTitle = MODES[feature].title

  const requestHideSection = () => {
    if (
      window.confirm(
        `Are you sure you want to hide ${sectionTitle}? You can make it visible again in your site settings later.`
      )
    ) {
      api
        .mutation(`/api/${encodeURIComponent(site.domain)}/disable-feature`, {
          method: 'PUT',
          body: { feature: feature }
        })
        .then(() => onHideAction?.())
        .catch((error) => {
          if (!(error instanceof api.ApiError)) {
            throw error
          }
        })
    }
  }

  function renderCallToAction() {
    return (
      <a
        href={callToAction.link}
        className={buttonClassName({
          theme: 'primary',
          className: 'ml-2 sm:ml-4'
        })}
      >
        {callToAction.action} &rarr;
      </a>
    )
  }

  function renderHideButton() {
    return (
      <button
        onClick={requestHideSection}
        className={buttonClassName({ theme: 'secondary' })}
      >
        Hide this report
      </button>
    )
  }

  function renderSecondaryCallToAction() {
    if (!secondaryCallToAction) {
      return null
    }
    return (
      <a
        href={secondaryCallToAction.link}
        className={buttonClassName({
          theme: 'secondary'
        })}
      >
        {secondaryCallToAction.action}
      </a>
    )
  }

  return (
    <div
      className={classNames(
        'relative size-full flex items-center justify-center',
        previewMock && 'md:h-[400px]'
      )}
    >
      {previewMock && (
        <div
          aria-hidden="true"
          className="hidden md:block pointer-events-none absolute inset-0 blur-sm opacity-50"
        >
          {previewMock}
        </div>
      )}
      <div
        className={classNames(
          'relative py-3 max-w-2xl',
          previewMock &&
            'max-w-lg md:p-8 md:bg-white md:dark:bg-gray-800 md:border md:border-gray-100 md:dark:border-gray-750 md:rounded-lg md:shadow-xl'
        )}
      >
        {previewMock && (
          <div className="flex justify-center mb-3">
            <BusinessPill />
          </div>
        )}
        <div className="text-center mt-2 text-gray-800 dark:text-gray-200 font-medium text-pretty">
          {title}
        </div>
        <div className="text-center mt-4 font-small text-sm text-gray-500 dark:text-gray-300 text-pretty">
          {info}
        </div>
        <div className="text-xs sm:text-sm flex mt-6 mb-1 justify-center">
          {typeof onHideAction === 'function' && renderHideButton()}
          {renderSecondaryCallToAction()}
          {renderCallToAction()}
        </div>
      </div>
    </div>
  )
}
