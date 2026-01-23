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

    this.handlePeriodShift = (shiftFn) => {
      if (this.dates.length) {
        const updated = shiftFn.bind(this)()

        if (updated) {
          this.debouncedPushEvent()
        }

        this.periodLabel.innerText = this.labels[this.currentIndex]
        this.prevPeriodButton.dataset.disabled = `${this.currentIndex == 0}`
        this.nextPeriodButton.dataset.disabled = `${this.currentIndex == this.dates.length - 1}`
      }
    }

    this.addListener('keyboard-change-period', window, (e) => {
      const periodLink = this.el.querySelector(
        `a[data-keyboard-shortcut="${e.detail.key}"]`
      )
      if (periodLink) {
        periodLink.click()
      }
    })

    this.addListener('keyboard-shift-period', window, (e) => {
      if (e.detail.key === 'ArrowLeft') {
        this.handlePeriodShift(prevPeriod)
      }

      if (e.detail.key === 'ArrowRight') {
        this.handlePeriodShift(nextPeriod)
      }
    })

    this.addListener('click', this.el, (e) => {
      const button = e.target.closest('button')

      if (button === this.prevPeriodButton) {
        this.handlePeriodShift(prevPeriod)
      }

      if (button === this.nextPeriodButton) {
        this.handlePeriodShift(nextPeriod)
      }
    })
  }
})
