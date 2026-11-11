import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "prusa", "bambu"]

  connect() {
    this.toggle()
  }

  toggle() {
    const bambu = this.typeTarget.value === "bambu"
    this.prusaTarget.hidden = bambu
    this.bambuTarget.hidden = !bambu
  }
}
