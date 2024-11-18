/** @format */

import React, {
  DetailedHTMLProps,
  forwardRef,
  HTMLAttributes,
  ReactNode
} from 'react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import classNames from 'classnames'
import { Transition } from '@headlessui/react'
import {
  AppNavigationLink,
  AppNavigationTarget
} from '../navigation/use-app-navigate'
import { NavigateOptions } from 'react-router-dom'

export const ToggleDropdownButton = forwardRef<
  HTMLDivElement,
  {
    variant?: 'ghost' | 'button'
    withDropdownIndicator?: boolean
    className?: string
    currentOption: ReactNode
    children: ReactNode
    onClick: () => void
    dropdownContainerProps: DetailedHTMLProps<
      HTMLAttributes<HTMLButtonElement>,
      HTMLButtonElement
    >
  }
>(
  (
    {
      className,
      currentOption,
      withDropdownIndicator,
      children,
      onClick,
      dropdownContainerProps,
      ...props
    },
    ref
  ) => {
    const { variant } = { variant: 'button', ...props }
    const sharedButtonClass =
      'flex items-center rounded text-sm leading-tight px-2 py-2 h-9'

    const buttonClass = {
      ghost:
        'text-gray-500 hover:text-gray-800 hover:bg-gray-200 dark:hover:text-gray-200 dark:hover:bg-gray-900',
      button:
        'w-full justify-between bg-white dark:bg-gray-800 shadow text-gray-800 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-900'
    }[variant]

    return (
      <div className={className} ref={ref}>
        <button
          onClick={onClick}
          className={classNames(sharedButtonClass, buttonClass)}
          tabIndex={0}
          aria-haspopup="true"
          {...dropdownContainerProps}
        >
          <span className="truncate block font-medium">{currentOption}</span>
          {!!withDropdownIndicator && (
            <ChevronDownIcon className="hidden lg:inline-block h-4 w-4 md:h-5 md:w-5 ml-1 md:ml-2 text-gray-500" />
          )}
        </button>
        {children}
      </div>
    )
  }
)

export const DropdownMenuWrapper = forwardRef<
  HTMLDivElement,
  { innerContainerClassName?: string; children: ReactNode } & DetailedHTMLProps<
    HTMLAttributes<HTMLDivElement>,
    HTMLDivElement
  >
>(({ children, className, innerContainerClassName, ...props }, ref) => {
  return (
    <div
      ref={ref}
      {...props}
      className={classNames(
        'absolute left-0 right-0 mt-2 origin-top-right z-10',
        className
      )}
    >
      <Transition
        as="div"
        show={true}
        appear={true}
        enter="transition ease-out duration-100"
        enterFrom="opacity-0 scale-95"
        enterTo="opacity-100 scale-100"
        leave="transition ease-in duration-75"
        leaveFrom="opacity-100 scale-100"
        leaveTo="opacity-0 scale-95"
        className={classNames(
          'rounded-md shadow-lg bg-white dark:bg-gray-800 ring-1 ring-black ring-opacity-5 font-medium text-gray-800 dark:text-gray-200',
          innerContainerClassName
        )}
      >
        {children}
      </Transition>
    </div>
  )
})

export const DropdownLinkGroup = ({
  className,
  children,
  ...props
}: DetailedHTMLProps<HTMLAttributes<HTMLDivElement>, HTMLDivElement>) => (
  <div
    {...props}
    className={classNames(
      className,
      'py-1 border-gray-200 dark:border-gray-500 border-b last:border-none'
    )}
  >
    {children}
  </div>
)

export const DropdownNavigationLink = ({
  children,
  active,
  className,
  actions,
  path,
  params,
  search,
  navigateOptions,
  onLinkClick,
  ...props
}: AppNavigationTarget & {
  navigateOptions?: NavigateOptions
} & DetailedHTMLProps<HTMLAttributes<HTMLDivElement>, HTMLDivElement> & {
    active?: boolean
    onLinkClick?: () => void
    actions?: ReactNode
  }) => (
  <div
    className={classNames(
      { 'font-bold': !!active },
      'flex items-center justify-between',
      'text-sm leading-tight',
      {'hover:bg-gray-100 hover:text-gray-900 dark:hover:bg-gray-900 dark:hover:text-gray-100': !props['aria-disabled']},
      {'cursor-not-allowed text-gray-500': props['aria-disabled']},
      !!actions && 'pr-4',
      className
    )}
    {...props}
  >
    <AppNavigationLink
      className={classNames(
        'flex items-center justify-between w-full py-2',
        actions ? 'pl-4' : 'px-4',
        {'cursor-not-allowed': props['aria-disabled']},
      )}
      path={path}
      params={params}
      search={search}
      onClick={onLinkClick}
      {...navigateOptions}
    >
      {children}
    </AppNavigationLink>
    {!!actions && actions}
  </div>
)
