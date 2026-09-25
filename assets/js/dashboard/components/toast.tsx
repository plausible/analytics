import React, { useEffect, useState } from 'react'
import classNames from 'classnames'
import { CheckCircleIcon } from '@heroicons/react/24/outline'
import { XMarkIcon } from '@heroicons/react/20/solid'

type Toast = {
  title?: string
  message: string
}

const TOAST_TTL_MS = 4000
const TOAST_LEAVE_MS = 100

type Phase = 'enter' | 'shown' | 'leave'
type Listener = (toast: Toast) => void

const listeners = new Set<Listener>()

export function showToast(toast: Toast) {
  listeners.forEach((listener) => listener(toast))
}

export function ToastHost() {
  const [toast, setToast] = useState<Toast | null>(null)
  const [phase, setPhase] = useState<Phase>('enter')

  useEffect(() => {
    const listener: Listener = (next) => {
      setToast(next)
      setPhase('enter')
    }
    listeners.add(listener)
    return () => {
      listeners.delete(listener)
    }
  }, [])

  useEffect(() => {
    if (!toast || phase !== 'enter') {
      return
    }
    let cancelled = false
    const frame = window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        if (!cancelled) {
          setPhase('shown')
        }
      })
    })
    return () => {
      cancelled = true
      window.cancelAnimationFrame(frame)
    }
  }, [toast, phase])

  useEffect(() => {
    if (!toast || phase !== 'shown') {
      return
    }
    const hide = window.setTimeout(() => setPhase('leave'), TOAST_TTL_MS)
    return () => window.clearTimeout(hide)
  }, [toast, phase])

  useEffect(() => {
    if (!toast || phase !== 'leave') {
      return
    }
    const clear = window.setTimeout(() => setToast(null), TOAST_LEAVE_MS)
    return () => window.clearTimeout(clear)
  }, [toast, phase])

  if (!toast) {
    return null
  }

  return (
    <div className="z-50 fixed inset-0 flex items-end justify-center px-4 py-6 pointer-events-none sm:p-6 sm:items-start sm:justify-end">
      <div
        role="status"
        className={classNames(
          'max-w-sm w-full bg-white dark:bg-gray-800 shadow-lg rounded-lg pointer-events-auto',
          phase === 'leave'
            ? 'transition ease-in duration-100'
            : 'transform transition ease-out duration-300',
          phase === 'enter' &&
            'translate-y-2 opacity-0 sm:translate-y-0 sm:translate-x-2',
          phase === 'shown' && 'translate-y-0 opacity-100 sm:translate-x-0',
          phase === 'leave' && 'opacity-0'
        )}
      >
        <div className="rounded-lg ring-1/5 ring-black overflow-hidden">
          <div className="p-4">
            <div className="flex items-start">
              <div className="shrink-0">
                <CheckCircleIcon className="size-6 text-green-400" />
              </div>
              <div className="ml-3 w-0 flex-1 pt-0.5">
                <p className="text-sm leading-5 font-medium text-gray-900 dark:text-gray-100">
                  {toast.title ?? 'Success!'}
                </p>
                <p className="mt-1 text-sm leading-5 text-gray-500 dark:text-gray-200">
                  {toast.message}
                </p>
              </div>
              <div className="ml-4 shrink-0 flex">
                <button
                  type="button"
                  className="inline-flex text-gray-400 focus:outline-hidden focus:text-gray-500 dark:focus:text-gray-200 transition ease-in-out duration-150"
                  aria-label="Close toast"
                  onClick={() => setPhase('leave')}
                >
                  <XMarkIcon className="size-5" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
