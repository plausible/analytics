// Lets people add/remove member rows and pick a role instantly, without
// waiting on a server round trip - this is a JS hook rather than plain
// LiveView because that latency would be noticeable for something the
// server doesn't need to know about until the form is actually submitted.

const ROW_ID_PLACEHOLDER = '__ROW_ID__'

const capitalize = (s) => s.charAt(0).toUpperCase() + s.slice(1)

export default {
  mounted() {
    this.template = this.el.querySelector('template[data-row-template]')
    this.list = this.el.querySelector('[data-row-list]')
    this.maxRows = parseInt(this.el.dataset.maxRows, 10)
    this.addButton = this.el.querySelector('[data-add-row]')

    this.addButton.addEventListener('click', () => this.addRow())

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

    this.updateAddButtonState()
  },

  destroyed() {
    document.removeEventListener('click', this.handleOutsideClick)
  },

  addRow() {
    if (this.list.children.length >= this.maxRows) return

    const rowId =
      window.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random()}`

    const html = this.template.innerHTML.replaceAll(ROW_ID_PLACEHOLDER, rowId)
    const wrapper = document.createElement('div')
    wrapper.innerHTML = html
    const row = wrapper.firstElementChild

    this.list.appendChild(row)
    this.wireRolePicker(row.querySelector('[data-role-picker]'))
    this.updateAddButtonState()
    row.querySelector('input[type="email"]').focus()
  },

  updateAddButtonState() {
    const atLimit = this.list.children.length >= this.maxRows

    this.addButton.classList.toggle('hidden', atLimit)
    this.addButton.classList.toggle('inline-flex', !atLimit)
  },

  removeRow(button) {
    button.closest('[data-row]').remove()
    this.updateAddButtonState()
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
