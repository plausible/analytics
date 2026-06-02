import React, { ReactNode } from 'react'
import { ExclamationTriangleIcon } from '@heroicons/react/24/outline'
import classNames from 'classnames'

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
  recommendedMaxLength?: number
}

const LabeledField = ({
  label,
  id,
  value,
  recommendedMaxLength,
  children
}: Pick<
  LabeledFieldProps,
  'label' | 'id' | 'value' | 'recommendedMaxLength'
> & {
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
    {recommendedMaxLength !== undefined && (
      <CharacterCounter
        id={`${id}-counter`}
        length={getCharacterCount(value)}
        recommendedMaxLength={recommendedMaxLength}
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
  recommendedMaxLength
}: LabeledFieldProps) => (
  <LabeledField
    label={label}
    id={id}
    value={value}
    recommendedMaxLength={recommendedMaxLength}
  >
    <input
      autoComplete="off"
      id={id}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      aria-describedby={
        recommendedMaxLength !== undefined ? `${id}-counter` : undefined
      }
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
  recommendedMaxLength,
  rows = 3
}: LabeledFieldProps & {
  rows?: number
}) => (
  <LabeledField
    label={label}
    id={id}
    value={value}
    recommendedMaxLength={recommendedMaxLength}
  >
    <textarea
      autoComplete="off"
      id={id}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      rows={rows}
      aria-describedby={
        recommendedMaxLength !== undefined ? `${id}-counter` : undefined
      }
      className={classNames(fieldClassName, 'resize-y leading-5')}
    />
  </LabeledField>
)

const CharacterCounter = ({
  id,
  length,
  recommendedMaxLength
}: {
  id: string
  length: number
  recommendedMaxLength: number
}) => {
  const overLimit = length > recommendedMaxLength
  return (
    <p
      id={id}
      className="mt-1.5 text-xs text-gray-500 dark:text-gray-400"
      aria-live="polite"
    >
      {`Recommended: ${recommendedMaxLength} characters. You've used `}
      <span
        className={classNames('font-semibold', {
          'text-red-500 dark:text-red-400': overLimit
        })}
      >
        {length}
      </span>
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
  options: { type: T; name: string; description: string }[]
  idPrefix: string
}) => {
  return (
    <div className="flex flex-col gap-y-2">
      {options.map(({ type, name, description }) => (
        <div key={type}>
          <div className="flex">
            <input
              checked={value === type}
              id={`${idPrefix}-${type}`}
              type="radio"
              value=""
              onChange={() => onChange(type)}
              className="mt-px size-4.5 cursor-pointer text-indigo-600 dark:bg-transparent border-gray-400 dark:border-gray-600 checked:border-indigo-600 dark:checked:border-white"
            />
            <label
              htmlFor={`${idPrefix}-${type}`}
              className="block ml-3 text-sm font-medium dark:text-gray-100 flex flex-col flex-inline"
            >
              <div>{name}</div>
              <div className="text-gray-500 dark:text-gray-400 text-sm font-normal">
                {description}
              </div>
            </label>
          </div>
        </div>
      ))}
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

export const TypeDisabledMessage = ({
  message
}: {
  message: ReactNode | null
}) => {
  if (!message) return null

  return (
    <div className="mt-2 flex gap-x-2 text-sm">
      <ExclamationTriangleIcon className="mt-1 block w-4 h-4 shrink-0" />
      <div>{message}</div>
    </div>
  )
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
