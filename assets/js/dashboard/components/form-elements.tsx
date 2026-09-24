import React, { ReactNode } from 'react'
import classNames from 'classnames'
import { Tooltip } from '../util/tooltip'

export const getCharacterCount = (value: string): number => [...value].length

export const isOverMaxLength = (value: string, maxLength: number): boolean =>
  getCharacterCount(value) > maxLength

const fieldClassName =
  'block px-3.5 py-2.5 w-full text-sm dark:text-gray-300 rounded-md border border-gray-300 dark:border-gray-750 dark:bg-gray-750 focus:outline-none focus:ring-3 focus:ring-indigo-500/20 dark:focus:ring-indigo-500/25 focus:border-indigo-500'

interface LabeledFieldProps {
  label: string
  id: string
  value: string
  onChange: (value: string) => void
  placeholder: string
  maxLength?: number
}

const LabeledField = ({
  label,
  id,
  value,
  maxLength,
  children
}: Pick<LabeledFieldProps, 'label' | 'id' | 'value' | 'maxLength'> & {
  children: ReactNode
}) => (
  <div className="flex flex-col">
    <label
      htmlFor={id}
      className="block mb-1.5 text-sm font-medium dark:text-gray-100 text-gray-700 dark:text-gray-300"
    >
      {label}
    </label>
    {children}
    {maxLength !== undefined && (
      <CharacterCounter
        id={`${id}-counter`}
        length={getCharacterCount(value)}
        maxLength={maxLength}
      />
    )}
  </div>
)

export const LabeledTextInput = ({
  label,
  id,
  value,
  onChange,
  placeholder,
  maxLength
}: LabeledFieldProps) => (
  <LabeledField label={label} id={id} value={value} maxLength={maxLength}>
    <input
      autoComplete="off"
      id={id}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      aria-describedby={maxLength !== undefined ? `${id}-counter` : undefined}
      className={fieldClassName}
    />
  </LabeledField>
)

export const LabeledTextarea = ({
  label,
  id,
  value,
  onChange,
  placeholder,
  maxLength,
  rows = 3
}: LabeledFieldProps & {
  rows?: number
}) => (
  <LabeledField label={label} id={id} value={value} maxLength={maxLength}>
    <textarea
      autoComplete="off"
      id={id}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      rows={rows}
      aria-describedby={maxLength !== undefined ? `${id}-counter` : undefined}
      className={classNames(fieldClassName, 'resize-y leading-5')}
    />
  </LabeledField>
)

const CharacterCounter = ({
  id,
  length,
  maxLength
}: {
  id: string
  length: number
  maxLength: number
}) => {
  const closeToLimit = length > maxLength * 0.8
  const visible = closeToLimit
  const overLimit = length > maxLength
  return (
    <p
      id={id}
      className="mt-1.5 text-xs text-gray-500 dark:text-gray-400"
      aria-live="polite"
    >
      {visible ? (
        <span>
          {`Max: ${maxLength} characters. You've used `}
          <span
            className={classNames('font-semibold', {
              'text-red-500 dark:text-red-400': overLimit
            })}
          >
            {length}
          </span>
        </span>
      ) : (
        // reserve 1 line worth of room to avoid layout jumps when the count appears
        <span className="opacity-0 select-none">&nbsp</span>
      )}
    </p>
  )
}

export const TypeSelector = <T extends string>({
  value,
  onChange,
  options,
  idPrefix
}: {
  value: T
  onChange: (value: T) => void
  options: {
    type: T
    name: string
    description: string
    disabled?: boolean
    pill?: ReactNode
    tooltipContent?: ReactNode
  }[]
  idPrefix: string
}) => {
  return (
    <div className="flex flex-col gap-y-2">
      {options.map(
        ({ type, name, description, disabled, pill, tooltipContent }) => {
          const row = (
            <label
              htmlFor={`${idPrefix}-${type}`}
              className={classNames(
                'flex flex-col text-sm font-medium dark:text-gray-100',
                disabled && 'cursor-not-allowed'
              )}
            >
              <div className="flex items-center gap-x-3">
                <input
                  checked={value === type}
                  id={`${idPrefix}-${type}`}
                  type="radio"
                  value=""
                  onChange={() => onChange(type)}
                  disabled={disabled}
                  className={classNames(
                    'size-4.5 text-indigo-600 dark:bg-transparent border-gray-400 dark:border-gray-600 checked:border-indigo-600 dark:checked:border-white',
                    disabled
                      ? 'cursor-not-allowed opacity-50'
                      : 'cursor-pointer'
                  )}
                />
                <div className="flex items-center gap-x-2">
                  <span className={classNames(disabled && 'opacity-50')}>
                    {name}
                  </span>
                  {pill}
                </div>
              </div>
              <div
                className={classNames(
                  'ml-[1.875rem] text-gray-500 dark:text-gray-400 text-sm font-normal',
                  disabled && 'opacity-50'
                )}
              >
                {description}
              </div>
            </label>
          )

          return (
            <div key={type}>
              {tooltipContent ? (
                <Tooltip info={tooltipContent}>{row}</Tooltip>
              ) : (
                row
              )}
            </div>
          )
        }
      )}
    </div>
  )
}

export type OptionDisabledMessageType =
  | 'upgrade-subscription-yourself'
  | 'upgrade-subscription-reach-out'
  | 'no-permissions'

export const getOptionDisabledMessage = ({
  optionAvailable,
  userHasOptionPermissions,
  userCanUpgradeSubscription
}: {
  optionAvailable: boolean
  userHasOptionPermissions: boolean
  userCanUpgradeSubscription: boolean
}): null | OptionDisabledMessageType => {
  if (!userHasOptionPermissions) {
    return 'no-permissions'
  }
  if (!optionAvailable) {
    if (userCanUpgradeSubscription) {
      return 'upgrade-subscription-yourself'
    }
    return 'upgrade-subscription-reach-out'
  }
  return null
}

/** Keep this component styled the same as checkboxes in PlausibleWeb.Live.Installation.Instructions */
export const Checkbox = ({
  id,
  checked,
  onChange,
  children
}: React.DetailedHTMLProps<
  React.InputHTMLAttributes<HTMLInputElement>,
  HTMLInputElement
>) => {
  return (
    <label
      className="text-sm block font-medium dark:text-gray-100 font-normal gap-x-2 flex flex-inline items-center justify-start"
      htmlFor={id}
    >
      <input
        className="block size-5 rounded-sm dark:bg-gray-600 border-gray-300 dark:border-gray-600 text-indigo-600"
        id={id}
        type="checkbox"
        checked={checked}
        onChange={onChange}
      />
      {children}
    </label>
  )
}
