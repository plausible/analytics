/**
 * Hook widget for optimistic updates to the datepicker
 * label when relative date is changed (prev/next period
 * arrow keys).
 */

import { buildHook } from './hook_builder'

function prevPeriod() {
  if (this.currentIndex === 0) {
    // add disabled class if it doesn't exist already
    console.log('prev disabled')
  } else {
    this.currentIndex--
    this.pushEventTo(this.target, 'set-relative-date', { date: this.dates[this.currentIndex] })
  }
}

function nextPeriod() {
  if (this.currentIndex === this.dates.length - 1) {
    // add disabled class if it doesn't exist already
    console.log('next disabled')
  } else {
    this.currentIndex++
    this.pushEventTo(this.target, 'set-relative-date', { date: this.dates[this.currentIndex] })
  }
}

export default buildHook({
  initialize() {
    this.target = this.el.dataset.target

    this.currentIndex = parseInt(this.el.dataset.currentIndex)
    this.dates = JSON.parse(this.el.dataset.dates)
    this.labels = JSON.parse(this.el.dataset.labels)

    this.prevPeriodButton = this.el.querySelector('button#prev-period')
    this.nextPeriodButton = this.el.querySelector('button#next-period')
    this.periodLabel = this.el.querySelector('#period-label')

    this.addListener('click', this.el, (e) => {
      if (this.dates.length) {
        const button = e.target.closest('button')
  
        if (button === this.prevPeriodButton) {
          prevPeriod.bind(this)()
        }
  
        if (button === this.nextPeriodButton) {
          nextPeriod.bind(this)()
        }
  
        this.periodLabel.innerText = this.labels[this.currentIndex]
        this.prevPeriodButton.dataset.disabled = `${this.currentIndex == 0}`
        this.nextPeriodButton.dataset.disabled = `${this.currentIndex == this.dates.length - 1}`
      }
    })
  }
})
