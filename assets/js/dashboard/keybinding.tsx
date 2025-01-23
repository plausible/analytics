/* @format */
import React, { ReactNode, useCallback, useEffect } from 'react'
import {
  AppNavigationTarget,
  useAppNavigate
} from './navigation/use-app-navigate'

/**
 * Returns whether a keydown or keyup event should be ignored or not.
 *
 * Keybindings are ignored when a modifier key is pressed, for example, if the
 * keybinding is <i>, but the user pressed <Ctrl-i> or <Meta-i>, the event
 * should be discarded.
 *
 * Another case for ignoring a keybinding, is when the user is typing into a
 * form, and presses the keybinding. For example, if the keybinding is <p> and
 * the user types <apple>, the event should also be discarded.
 *
 * @param {*} event - Captured HTML DOM event
 * @return {boolean} Whether the event should be ignored or not.
 *
 */

export const isModifierPressed = (event: KeyboardEvent): boolean =>
  event.ctrlKey || event.metaKey || event.altKey || event.keyCode == 229

export const isTyping = (event: KeyboardEvent): boolean => {
  const targetElement = event.target as Element | undefined
  return (
    event.isComposing ||
    targetElement?.tagName == 'INPUT' ||
    targetElement?.tagName == 'TEXTAREA'
  )
}

export function isKeyPressed(
  event: KeyboardEvent,
  {
    keyboardKey,
    shouldIgnoreWhen
  }: {
    keyboardKey: string
    shouldIgnoreWhen?: Array<(event: KeyboardEvent) => boolean>
  }
): boolean {
  if (event.key.toLowerCase() !== keyboardKey.toLowerCase()) {
    return false
  }
  if (
    shouldIgnoreWhen?.length &&
    shouldIgnoreWhen.some((shouldIgnore) => shouldIgnore(event))
  ) {
    return false
  }
  return true
}

type KeyboardEventType = keyof Pick<
  GlobalEventHandlersEventMap,
  'keyup' | 'keydown' | 'keypress'
>

type KeybindOptions = {
  keyboardKey: string
  type: KeyboardEventType
  handler: (event: KeyboardEvent) => void
  shouldIgnoreWhen?: Array<(event: KeyboardEvent) => boolean>
  target?: Document | HTMLElement | null
}

function useKeybind({
  keyboardKey,
  type,
  handler,
  shouldIgnoreWhen = [],
  target
}: KeybindOptions) {
  const wrappedHandler = useCallback(
    (event: KeyboardEvent) => {
      if (isKeyPressed(event, { keyboardKey, shouldIgnoreWhen })) {
        handler(event)
      }
    },
    [keyboardKey, handler, shouldIgnoreWhen]
  ) as EventListener

  useEffect(() => {
    const registerKeybind = (t: HTMLElement | Document) =>
      t.addEventListener(type, wrappedHandler)

    const deregisterKeybind = (t: HTMLElement | Document) =>
      t.removeEventListener(type, wrappedHandler)

    if (target) {
      registerKeybind(target)
    }

    return () => {
      if (target) {
        deregisterKeybind(target)
      }
    }
  }, [target, type, wrappedHandler])
}

export function Keybind(opts: KeybindOptions) {
  useKeybind(opts)

  return null
}

export function NavigateKeybind({
  keyboardKey,
  type,
  navigateProps
}: {
  keyboardKey: string
  type: KeyboardEventType
  navigateProps: AppNavigationTarget
}) {
  const navigate = useAppNavigate()
  const handler = useCallback(() => {
    navigate({ ...navigateProps })
  }, [navigateProps, navigate])

  return (
    <Keybind
      keyboardKey={keyboardKey}
      type={type}
      handler={handler}
      shouldIgnoreWhen={[isModifierPressed, isTyping]}
      target={document}
    />
  )
}

export function KeybindHint({ children }: { children: ReactNode }) {
  return (
    <kbd className="rounded border border-gray-200 dark:border-gray-600 px-2 font-mono font-normal text-xs text-gray-400">
      {children}
    </kbd>
  )
}
