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
export function shouldIgnoreKeypress(event) {
  const modifierPressed = event.ctrlKey || event.metaKey || event.altKey || event.keyCode == 229
  const isTyping = event.isComposing || event.target.tagName == "INPUT" || event.target.tagName == "TEXTAREA"

  return modifierPressed || isTyping
}

/**
 * Returns whether the given keybinding has been pressed and should be
 * processed. Events can be ignored based on `shouldIgnoreKeypress(event)`.
 *
 * @param {string} keybinding - The target key to checked, e.g. `"i"`.
 * @return {boolean} Whether the event should be processed or not.
 *
 */
export function isKeyPressed(event, keybinding) {
  const keyPressed = event.key.toLowerCase() == keybinding.toLowerCase()
  return keyPressed && !shouldIgnoreKeypress(event)
}
