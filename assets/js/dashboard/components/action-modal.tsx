import React, { ReactNode } from 'react'
import ModalWithRouting from '../stats/modals/modal'
import classNames from 'classnames'
import { ExclamationTriangleIcon } from '@heroicons/react/24/outline'

export const primaryNeutralButtonClassName = 'button !px-3'

export const secondaryButtonClassName = classNames(
  'button !px-3.5',
  'border !border-gray-300 dark:!border-gray-700 !bg-white dark:!bg-gray-700 !text-gray-800 dark:!text-gray-100 hover:!text-gray-900 hover:!shadow-sm dark:hover:!bg-gray-600 dark:hover:!text-white'
)

export const primaryNegativeButtonClassName = classNames(
  'button !px-3.5',
  'items-center !bg-red-500 dark:!bg-red-500 hover:!bg-red-600 dark:hover:!bg-red-700 whitespace-nowrap',
  'disabled:!bg-red-400 disabled:cursor-not-allowed'
)

export const ActionModal = ({
  children,
  onClose
}: {
  children: ReactNode
  onClose: () => void
}) => (
  <ModalWithRouting maxWidth="460px" className="p-6 min-h-fit" onClose={onClose}>
    <div className="mb-8 dark:text-gray-100">{children}</div>
  </ModalWithRouting>
)

export const FormTitle = ({
  className,
  children
}: {
  className?: string
  children?: ReactNode
}) => (
  <h1
    className={classNames(
      'text-lg font-medium text-gray-900 dark:text-gray-100 leading-7',
      className
    )}
  >
    {children}
  </h1>
)

export const ButtonsRow = ({
  className,
  children
}: {
  className?: string
  children?: ReactNode
}) => (
  <div className={classNames('mt-8 flex gap-x-3 items-center', className)}>
    {children}
  </div>
)

export const SaveButton = ({
  disabled,
  onSave
}: {
  disabled: boolean
  onSave: () => void
}) => (
  <button
    className={primaryNeutralButtonClassName}
    type="button"
    disabled={disabled}
    onClick={disabled ? () => {} : onSave}
  >
    Save
  </button>
)

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

export const LabeledTextInput = ({
  label,
  id,
  value,
  onChange,
  placeholder
}: {
  label: string
  id: string
  value: string
  onChange: (value: string) => void
  placeholder: string
}) => (
  <>
    <label
      htmlFor={id}
      className="block mb-1.5 text-sm font-medium dark:text-gray-100 text-gray-700 dark:text-gray-300"
    >
      {label}
    </label>
    <input
      autoComplete="off"
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      id={id}
      className="block px-3.5 py-2.5 w-full text-sm dark:text-gray-300 rounded-md border border-gray-300 dark:border-gray-750 dark:bg-gray-750 focus:outline-none focus:ring-3 focus:ring-indigo-500/20 dark:focus:ring-indigo-500/25 focus:border-indigo-500"
    />
  </>
)

export const TypeSelector = <T extends string>({
  value,
  onChange,
  options
}: {
  value: T
  onChange: (value: T) => void
  options: { type: T; name: string; description: string }[]
}) => (
  <div className="mt-6 flex flex-col gap-y-4">
    {options.map(({ type, name, description }) => (
      <div key={type}>
        <div className="flex">
          <input
            checked={value === type}
            id={`segment-type-${type}`}
            type="radio"
            value=""
            onChange={() => onChange(type)}
            className="mt-px size-4.5 cursor-pointer text-indigo-600 dark:bg-transparent border-gray-400 dark:border-gray-600 checked:border-indigo-600 dark:checked:border-white"
          />
          <label
            htmlFor={`segment-type-${type}`}
            className="block ml-3 text-sm font-medium dark:text-gray-100 flex flex-col flex-inline"
          >
            <div>{name}</div>
            <div className="text-gray-500 dark:text-gray-400 mb-2 text-sm">
              {description}
            </div>
          </label>
        </div>
      </div>
    ))}
  </div>
)
