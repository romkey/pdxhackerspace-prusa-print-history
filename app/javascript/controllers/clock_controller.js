import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['display']

  connect() {
    this.tick()
    this.timer = window.setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    window.clearInterval(this.timer)
  }

  tick() {
    const now = new Date()
    this.displayTarget.textContent = this.format(now)
  }

  format(date) {
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')
    const seconds = String(date.getSeconds()).padStart(2, '0')
    const weekday = date.toLocaleDateString(undefined, { weekday: 'long' })
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')

    return `${hours}:${minutes}:${seconds} ${weekday} ${year}-${month}-${day}`
  }
}
