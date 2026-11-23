import { Controller } from '@hotwired/stimulus'

// Asks before submitting a form that Turbo does not handle (data-turbo="false"), where
// data-turbo-confirm has no effect.
export default class extends Controller {
  static values = { message: String }

  ask(event) {
    if (!window.confirm(this.messageValue)) event.preventDefault()
  }
}
