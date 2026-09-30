// Lets people add/remove member rows and pick a role instantly, without
// waiting on a server round trip - this is a JS hook rather than plain
// LiveView because that latency would be noticeable for something the
// server doesn't need to know about until the form is actually submitted.
//
// Every row up to the team member limit is rendered by the server on
// mount, all but the first one hidden - that way each row's role picker
// (Prima.Listbox, see prima_listbox.ex) mounts as an ordinary LiveView
// hook the normal way. No row is ever created or destroyed after mount:
// "add" reveals the next hidden row, "remove" hides one and moves it to
// the end so a later "add" doesn't re-insert it in the middle.

export default {
  mounted() {
    this.list = this.el.querySelector('[data-row-list]')
    this.addButton = this.el.querySelector('[data-add-row]')

    this.addButton.addEventListener('click', () => this.addRow())

    this.list.addEventListener('click', (e) => {
      const removeButton = e.target.closest('[data-remove-row]')
      if (removeButton) this.removeRow(removeButton)
    })

    this.updateAddButtonState()
  },

  addRow() {
    const nextRow = [...this.list.children].find((row) =>
      row.classList.contains('hidden')
    )
    if (!nextRow) return

    nextRow.classList.remove('hidden')
    nextRow.classList.add('flex')
    nextRow.querySelector('input[type="email"]').focus()
    this.updateAddButtonState()
  },

  removeRow(button) {
    const row = button.closest('[data-row]')

    row.classList.remove('flex')
    row.classList.add('hidden')
    this.resetRow(row)
    this.list.appendChild(row)
    this.updateAddButtonState()
  },

  resetRow(row) {
    row.querySelector('input[type="email"]').value = ''

    // Goes through the same click handling Prima's Listbox hook wires up on
    // its options, so both the hidden form value and the displayed label end
    // up in sync exactly like a real user selection would - the row is
    // already hidden at this point, so the focus() that follows a selection
    // is a no-op instead of stealing focus.
    row.querySelector('[role="option"][data-value="viewer"]')?.click()
  },

  updateAddButtonState() {
    const visibleRows = this.list.querySelectorAll('[data-row]:not(.hidden)')
    const atLimit = visibleRows.length >= this.list.children.length

    this.addButton.classList.toggle('hidden', atLimit)
    this.addButton.classList.toggle('inline-flex', !atLimit)
  }
}
