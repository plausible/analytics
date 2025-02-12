/* @format */
import React, { ReactNode, RefObject, useCallback, useEffect } from 'react'
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
  targetRef?: 'document' | RefObject<HTMLElement> | null
}

function useKeybind({
  keyboardKey,
  type,
  handler,
  shouldIgnoreWhen = [],
  targetRef
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
    const element = targetRef === 'document' ? document : targetRef?.current
    const registerKeybind = (t: HTMLElement | Document) =>
      t.addEventListener(type, wrappedHandler)

    const deregisterKeybind = (t: HTMLElement | Document) =>
      t.removeEventListener(type, wrappedHandler)

    if (element) {
      registerKeybind(element)
    }

    return () => {
      if (element) {
        deregisterKeybind(element)
      }
    }
  }, [targetRef, type, wrappedHandler])
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
      targetRef="document"
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

/**
 * Rendering this component captures the Escape key on targetRef.current,
 * blurring the element on Escape, and stopping the event from propagating.
 * Needed to prevent other Escape handlers that may exist from running.
 */
export function BlurMenuButtonOnEscape({
  targetRef: targetRef
}: {
  targetRef: RefObject<HTMLElement>
}) {
  return (
    <Keybind
      keyboardKey="Escape"
      type="keyup"
      handler={(event) => {
        const t = event.target as HTMLElement | null
        if (typeof t?.blur === 'function') {
          if (t === targetRef.current) {
            t.blur()
            event.stopPropagation()
          }
        }
      }}
      targetRef={targetRef}
      shouldIgnoreWhen={[isModifierPressed, isTyping]}
    />
  )
}
