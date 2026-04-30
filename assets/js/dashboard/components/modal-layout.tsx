import React, { ReactNode } from 'react'
import { XMarkIcon } from '@heroicons/react/20/solid'
import ModalWithRouting from '../stats/modals/modal'

export function ModalLayout({
  title,
  onClose,
  children,
  maxWidth = '460px',
  allowScroll = true
}: {
  title: ReactNode
  onClose: () => void
  children: ReactNode
  maxWidth?: string
  allowScroll?: boolean
}) {
  return (
    <ModalWithRouting
      maxWidth={maxWidth}
      allowScroll={allowScroll}
      onClose={onClose}
    >
      <div className="flex flex-col gap-6 p-1 md:py-2 md:px-0">
        <div className="flex items-center justify-between gap-3">
          <h1 className="text-base font-bold leading-tight dark:text-gray-100">
            {title}
          </h1>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close modal"
            className="text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300"
          >
            <XMarkIcon className="size-4.5" />
          </button>
        </div>
        {children}
      </div>
    </ModalWithRouting>
  )
}

export function ModalFooter({ children }: { children: ReactNode }) {
  return <div className="flex gap-x-3 items-center justify-end">{children}</div>
}
