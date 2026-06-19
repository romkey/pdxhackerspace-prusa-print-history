import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["reason", "detailWrap", "detail"]

  connect() {
    this.syncDetail()
  }

  syncDetail() {
    const show = this.reasonTarget.value === "other"
    this.detailWrapTarget.hidden = !show
    this.detailTarget.required = show
    if (!show) this.detailTarget.value = ""
  }
}
