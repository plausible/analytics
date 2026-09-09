// Instantly adds/removes rows, and selects a role, in the "create team"
// form's member list - entirely client-side, no server round trip. Row and
// role state is plain form data (an email input and a hidden role input per
// row), read once when the form is submitted.
//
// Expects a `template[data-row-template]` (the row blueprint, with the
// literal placeholder `__ROW_ID__` standing in for the row id in its
// attributes), a `[data-row-list]` container to append/remove rows from, a
// `[data-add-row]` button, `[data-remove-row]` buttons, and role pickers
// built from a `details[data-role-picker]` (listbox-button pattern: a
// `<summary>` trigger, a `[role=listbox]` container, and `[data-role-item]`
// `[role=option]` buttons) containing a `[data-role-label]` span and a
// `[data-role-value]` hidden input.

const ROW_ID_PLACEHOLDER = '__ROW_ID__'

const capitalize = (s) => s.charAt(0).toUpperCase() + s.slice(1)

export default {
  mounted() {
    this.template = this.el.querySelector('template[data-row-template]')
    this.list = this.el.querySelector('[data-row-list]')

    this.el
      .querySelector('[data-add-row]')
      .addEventListener('click', () => this.addRow())

    this.list.addEventListener('click', (e) => {
      const removeButton = e.target.closest('[data-remove-row]')
      if (removeButton) return this.removeRow(removeButton)

      const roleItem = e.target.closest('[data-role-item]')
      if (roleItem) return this.selectRole(roleItem)
    })

    // Native <details> only closes on a second click on <summary> - close it
    // on an outside click too, like any other dropdown.
    this.handleOutsideClick = (e) => {
      this.list
        .querySelectorAll('[data-role-picker][open]')
        .forEach((details) => {
          if (!details.contains(e.target)) this.closeRolePicker(details)
        })
    }
    document.addEventListener('click', this.handleOutsideClick)

    this.list
      .querySelectorAll('[data-role-picker]')
      .forEach((details) => this.wireRolePicker(details))
  },

  destroyed() {
    document.removeEventListener('click', this.handleOutsideClick)
  },

  addRow() {
    const rowId =
      window.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random()}`

    const html = this.template.innerHTML.replaceAll(ROW_ID_PLACEHOLDER, rowId)
    const wrapper = document.createElement('div')
    wrapper.innerHTML = html
    const row = wrapper.firstElementChild

    this.list.appendChild(row)
    this.wireRolePicker(row.querySelector('[data-role-picker]'))
  },

  removeRow(button) {
    button.closest('[data-row]').remove()
  },

  selectRole(item) {
    const row = item.closest('[data-row]')
    const details = row.querySelector('[data-role-picker]')
    const items = [...details.querySelectorAll('[data-role-item]')]
    const role = item.dataset.roleItem

    row.querySelector('[data-role-value]').value = role
    row.querySelector('[data-role-label]').textContent = capitalize(role)
    items.forEach((i) => i.setAttribute('aria-selected', i === item))

    this.closeRolePicker(details)
    details.querySelector('summary').focus()
  },

  // Wires up the WAI-ARIA listbox-button keyboard pattern for a role picker:
  // arrow keys move a roving tabindex between options (opening the listbox on
  // first use if needed), Home/End jump to the ends, Escape closes and
  // returns focus to the trigger, and Tab closes the listbox on its way out.
  wireRolePicker(details) {
    const summary = details.querySelector('summary')
    const items = [...details.querySelectorAll('[data-role-item]')]

    details.addEventListener('toggle', () => {
      summary.setAttribute('aria-expanded', details.open)
      this.setRovingIndex(items, 0)
    })

    details.addEventListener('keydown', (e) => {
      const currentIndex = items.indexOf(document.activeElement)

      switch (e.key) {
        case 'ArrowDown':
          e.preventDefault()
          details.open = true
          this.focusItem(
            items,
            currentIndex === -1 ? 0 : (currentIndex + 1) % items.length
          )
          break

        case 'ArrowUp':
          e.preventDefault()
          details.open = true
          this.focusItem(
            items,
            currentIndex === -1
              ? items.length - 1
              : (currentIndex - 1 + items.length) % items.length
          )
          break

        case 'Home':
          if (!details.open) return
          e.preventDefault()
          this.focusItem(items, 0)
          break

        case 'End':
          if (!details.open) return
          e.preventDefault()
          this.focusItem(items, items.length - 1)
          break

        case 'Escape':
          if (!details.open) return
          this.closeRolePicker(details)
          summary.focus()
          break

        case 'Tab':
          this.closeRolePicker(details)
          break
      }
    })
  },

  focusItem(items, index) {
    this.setRovingIndex(items, index)
    items[index].focus()
  },

  setRovingIndex(items, index) {
    items.forEach((item, i) =>
      item.setAttribute('tabindex', i === index ? '0' : '-1')
    )
  },

  closeRolePicker(details) {
    details.removeAttribute('open')
  }
}
