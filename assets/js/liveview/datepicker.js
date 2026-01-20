/**
 * Hook widget for optimistic updates to the datepicker
 * label when relative date is changed (prev/next period
 * arrow keys).
 */

import { buildHook } from './hook_builder'

function prevPeriod() {
  if (this.currentIndex === 0) {
    return false
  } else {
    this.currentIndex--
    return true
  }
}

function nextPeriod() {
  if (this.currentIndex === this.dates.length - 1) {
    return false
  } else {
    this.currentIndex++
    return true
  }
}

function debounce(fn, delay) {
  let timer

  return function (...args) {
    clearTimeout(timer)

    timer = setTimeout(() => {
      fn.apply(this, args)
    }, delay)
  }
}

export default buildHook({
  initialize() {
    this.currentIndex = parseInt(this.el.dataset.currentIndex)
    this.dates = JSON.parse(this.el.dataset.dates)
    this.labels = JSON.parse(this.el.dataset.labels)

    this.prevPeriodButton = this.el.querySelector('button#prev-period')
    this.nextPeriodButton = this.el.querySelector('button#next-period')
    this.periodLabel = this.el.querySelector('#period-label')

    this.debouncedPushEvent = debounce(() => {
      this.pushEventTo(this.el.dataset.target, 'set-relative-date', {
        date: this.dates[this.currentIndex]
      })
    }, 500)

    this.addListener('click', this.el, (e) => {
      if (this.dates.length) {
        const button = e.target.closest('button')

        let updated = false

        if (button === this.prevPeriodButton) {
          updated = prevPeriod.bind(this)()
        }

        if (button === this.nextPeriodButton) {
          updated = nextPeriod.bind(this)()
        }

        if (updated) {
          this.debouncedPushEvent()
        }

        this.periodLabel.innerText = this.labels[this.currentIndex]
        this.prevPeriodButton.dataset.disabled = `${this.currentIndex == 0}`
        this.nextPeriodButton.dataset.disabled = `${this.currentIndex == this.dates.length - 1}`
      }
    })
  }
})
