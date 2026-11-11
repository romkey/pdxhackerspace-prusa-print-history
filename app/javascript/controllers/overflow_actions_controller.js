import { Controller } from "@hotwired/stimulus"

// Keeps every control in the row, and moves the ones that no longer fit into the more menu.
export default class extends Controller {
  static targets = ["bar", "items", "item", "more", "menu"]

  connect() {
    this.observer = new ResizeObserver(() => this.place())
    this.observer.observe(this.barTarget)
    this.place()
    document.fonts?.ready.then(() => {
      if (this.observer) this.place()
    })
  }

  disconnect() {
    this.observer?.disconnect()
    this.observer = null
  }

  place() {
    if (this.placing) return

    this.placing = true
    try {
      this.itemTargets.forEach((item) => {
        this.applyMode(item, "bar")
        this.itemsTarget.appendChild(item)
      })
      this.moreTarget.hidden = true
      if (!this.crowded()) return

      this.moreTarget.hidden = false
      const ordered = [...this.itemsTarget.children]
      for (let index = ordered.length - 1; index >= 0; index -= 1) {
        if (!this.crowded()) break

        const item = ordered[index]
        this.applyMode(item, "menu")
        this.menuTarget.prepend(item)
      }
      this.moreTarget.hidden = this.menuTarget.childElementCount === 0
    } finally {
      this.placing = false
    }
  }

  crowded() {
    const children = [...this.itemsTarget.children]
    if (children.length === 0) return false

    const needed = children.reduce((sum, child) => sum + this.outerWidth(child), 0)
    return needed + (this.gap() * (children.length - 1)) > this.itemsTarget.clientWidth + 1
  }

  outerWidth(element) {
    const style = getComputedStyle(element)
    return element.offsetWidth + (parseFloat(style.marginLeft) || 0) + (parseFloat(style.marginRight) || 0)
  }

  gap() {
    const value = parseFloat(getComputedStyle(this.itemsTarget).columnGap)
    return Number.isFinite(value) ? value : 0
  }

  applyMode(item, mode) {
    const nodes = [item, ...item.querySelectorAll("[data-overflow-actions-bar-class]")]
    nodes.forEach((node) => {
      const bar = node.dataset.overflowActionsBarClass
      const menu = node.dataset.overflowActionsMenuClass
      if (!bar || !menu) return

      node.className = mode === "menu" ? menu : bar
    })
  }
}
