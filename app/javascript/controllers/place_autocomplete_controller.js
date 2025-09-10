import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Lightweight Google Places via autocomplete API can be wired here if key available.
    // For now, leave as plain text; if window.google is present, instantiate Autocomplete.
    if (window.google && window.google.maps && window.google.maps.places) {
      this.autocomplete = new window.google.maps.places.Autocomplete(this.element, {
        fields: ["formatted_address", "geometry", "name"],
      })
      this.autocomplete.addListener("place_changed", () => {
        const place = this.autocomplete.getPlace()
        if (place && place.formatted_address) {
          this.element.value = place.formatted_address
        }
      })
    }
  }
}


