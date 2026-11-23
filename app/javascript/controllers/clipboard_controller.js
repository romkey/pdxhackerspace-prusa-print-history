import { Controller } from '@hotwired/stimulus'

// Copies the source target's value to the clipboard and briefly confirms on the button.
export default class extends Controller {
  static targets = ['source', 'button']

  select() {
    this.sourceTarget.select()
  }

  async copy() {
    await navigator.clipboard.writeText(this.sourceTarget.value)
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = 'Copied'
    window.setTimeout(() => { this.buttonTarget.textContent = original }, 1500)
  }
}
