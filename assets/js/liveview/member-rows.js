// Instantly adds/removes rows, and selects a role, in the "create team"
// form's member list - entirely client-side, no server round trip. Row and
// role state is plain form data (an email input and a hidden role input per
// row), read once when the form is submitted.
//
// Expects a `template[data-row-template]` (the row blueprint, with the
// literal placeholder `__ROW_ID__` standing in for the row id in its
// attributes), a `[data-row-list]` container to append/remove rows from, a
// `[data-add-row]` button, `[data-remove-row]` buttons, and role pickers
// built from a `details[data-role-picker]` containing a `[data-role-label]`
// span, a `[data-role-value]` hidden input, and `[data-role-item]` buttons.

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
  },

  addRow() {
    const rowId =
      window.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random()}`

    const html = this.template.innerHTML.replaceAll(ROW_ID_PLACEHOLDER, rowId)
    const wrapper = document.createElement('div')
    wrapper.innerHTML = html

    this.list.appendChild(wrapper.firstElementChild)
  },

  removeRow(button) {
    button.closest('[data-row]').remove()
  },

  selectRole(item) {
    const role = item.dataset.roleItem
    const row = item.closest('[data-row]')

    row.querySelector('[data-role-value]').value = role
    row.querySelector('[data-role-label]').textContent = capitalize(role)
    row.querySelector('[data-role-picker]').removeAttribute('open')
  }
}
