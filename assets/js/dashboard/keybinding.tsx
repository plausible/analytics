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
export function shouldIgnoreKeypress(event: KeyboardEvent) {
  const targetElement = event.target as Element | undefined
  const modifierPressed =
    event.ctrlKey || event.metaKey || event.altKey || event.keyCode == 229
  const isTyping =
    event.isComposing ||
    targetElement?.tagName == 'INPUT' ||
    targetElement?.tagName == 'TEXTAREA'

  return modifierPressed || isTyping
}

/**
 * Returns whether the given keybinding has been pressed and should be
 * processed. Events can be ignored based on `shouldIgnoreKeypress(event)`.
 *
 * @param {string} keyboardKey - The target key to checked, e.g. `"i"`.
 * @return {boolean} Whether the event should be processed or not.
 *
 */
export function isKeyPressed(event: KeyboardEvent, keyboardKey: string) {
  const keyPressed = event.key.toLowerCase() == keyboardKey.toLowerCase()
  return keyPressed && !shouldIgnoreKeypress(event)
}

type KeyboardEventType = keyof Pick<
  GlobalEventHandlersEventMap,
  'keyup' | 'keydown' | 'keypress'
>

export function Keybind({
  keyboardKey,
  type,
  handler
}: {
  keyboardKey: string
  type: KeyboardEventType
  handler: () => void
}) {
  const wrappedHandler = useCallback(
    (event: KeyboardEvent) => {
      if (isKeyPressed(event, keyboardKey)) {
        handler()
      }
    },
    [keyboardKey, handler]
  )

  useEffect(() => {
    const registerKeybind = () =>
      document.addEventListener(type, wrappedHandler)

    const deregisterKeybind = () =>
      document.removeEventListener(type, wrappedHandler)

    registerKeybind()

    return deregisterKeybind
  }, [type, wrappedHandler])

  return null
}

export function NavigateKeybind({
  keyboardKey,
  type,
  navigateProps
}: {
  keyboardKey: string
  type: 'keyup' | 'keydown' | 'keypress'
  navigateProps: AppNavigationTarget
}) {
  const navigate = useAppNavigate()
  const handler = useCallback(() => {
    navigate({ ...navigateProps })
  }, [navigateProps, navigate])

  return <Keybind keyboardKey={keyboardKey} type={type} handler={handler} />
}

export function KeybindHint({ children }: { children: ReactNode }) {
  return (
    <kbd className="rounded border border-gray-200 dark:border-gray-600 px-2 font-mono font-normal text-xs text-gray-400">
      {children}
    </kbd>
  )
}
