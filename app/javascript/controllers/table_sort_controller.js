import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  sort(event) {
    const header = event.currentTarget
    const table = header.closest("table")
    const body = table?.querySelector("tbody")
    if (!table || !body) return

    const headers = Array.from(table.querySelectorAll("thead th"))
    const columnIndex = headers.indexOf(header)
    if (columnIndex < 0) return

    const previousIndex = table.dataset.sortIndex
    const previousDirection = table.dataset.sortDirection || "asc"
    const nextDirection = previousIndex === String(columnIndex) && previousDirection === "asc" ? "desc" : "asc"
    const type = header.dataset.sortType || "text"

    const rows = Array.from(body.querySelectorAll("tr"))
    rows.sort((rowA, rowB) => {
      const valueA = this.readValue(rowA, columnIndex, type)
      const valueB = this.readValue(rowB, columnIndex, type)

      if (valueA == null && valueB == null) return 0
      if (valueA == null) return 1
      if (valueB == null) return -1

      if (type === "number") {
        return nextDirection === "asc" ? valueA - valueB : valueB - valueA
      }

      return nextDirection === "asc" ? valueA.localeCompare(valueB) : valueB.localeCompare(valueA)
    })

    rows.forEach((row) => body.appendChild(row))

    table.dataset.sortIndex = String(columnIndex)
    table.dataset.sortDirection = nextDirection
    this.updateHeaders(headers, header, nextDirection)
  }

  readValue(row, index, type) {
    const text = row.children[index]?.textContent?.trim() || ""
    if (text === "") return null

    if (type === "number") return this.parseNumber(text)

    return text.toLowerCase()
  }

  parseNumber(value) {
    const cleaned = value.replace(/[^0-9.-]/g, "")
    if (cleaned === "") return null

    const number = parseFloat(cleaned)
    return Number.isNaN(number) ? null : number
  }

  updateHeaders(headers, currentHeader, direction) {
    headers.forEach((header) => {
      header.classList.remove("is-sorted")
      header.removeAttribute("aria-sort")
    })

    currentHeader.classList.add("is-sorted")
    currentHeader.setAttribute("aria-sort", direction === "asc" ? "ascending" : "descending")
  }
}
