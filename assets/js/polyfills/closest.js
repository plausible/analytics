if (window.Element && !Element.prototype.closest) {
  Element.prototype.closest = function (s) {
    var matches = (this.document || this.ownerDocument).querySelectorAll(s),
      i,
      // eslint-disable-next-line @typescript-eslint/no-this-alias
      el = this
    do {
      i = matches.length
      // eslint-disable-next-line no-empty
      while (--i >= 0 && matches.item(i) !== el) {}
    } while (i < 0 && (el = el.parentElement))
    return el
  }
}
