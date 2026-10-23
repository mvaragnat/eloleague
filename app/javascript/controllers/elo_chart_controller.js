import { Controller } from "@hotwired/stimulus"

// A lightweight SVG chart renderer for ratings over time.
// Expects data via data-elo-chart-series-value: an array of
// [{ id, name, band_factor, points: [{ t: epoch_ms, r: rating, rd: deviation }, ...], resets: [{ t: epoch_ms }, ...] }]
// When points carry `rd`, a shaded band is drawn between r - k·rd and r + k·rd (k = band_factor, default 1).
// Each reset (balance patch) is drawn as a vertical yellow bar.

const SVG_NS = "http://www.w3.org/2000/svg"
const RESET_COLOR = "#facc15"
const Y_MIN = 1200
const Y_MAX = 1800
const Y_MID = 1500
const Y_STEP = 100

export default class extends Controller {
  static values = { series: Array }
  static targets = ["chart"]

  connect() {
    this.render()
  }

  render() {
    const series = this.seriesValue || []
    const svg = this.chartTarget
    while (svg.firstChild) svg.removeChild(svg.firstChild)

    if (!series.length) return

    // Flatten points to compute domains
    const allPoints = series.flatMap(s => (s.points || []).map(p => ({ ...p, band: (p.rd || 0) * (s.band_factor || 1) })))
    const allResets = series.flatMap(s => s.resets || [])
    if (!allPoints.length) return
    const allTimes = allPoints.map(p => p.t).concat(allResets.map(r => r.t))
    let minT = Math.min(...allTimes)
    let maxT = Math.max(...allTimes)
    const now = Date.now()
    if (now > maxT) maxT = now
    const minR = Math.min(...allPoints.map(p => p.r - p.band))
    const maxR = Math.max(...allPoints.map(p => p.r + p.band))

    const padding = { left: 40, right: 10, top: 10, bottom: 20 }
    const W = 800, H = 300
    const iw = W - padding.left - padding.right
    const ih = H - padding.top - padding.bottom

    // If all timestamps are the same, expand the window +/- 1 day to see ticks
    if (maxT === minT) {
      const day = 24 * 60 * 60 * 1000
      minT -= day
      maxT += day
    }

    // Fixed rating scale (1200..1800, centred on 1500), only widened by whole
    // tick steps when a rating or its uncertainty band falls outside it
    const yMin = Math.min(Y_MIN, Math.floor(minR / Y_STEP) * Y_STEP)
    const yMax = Math.max(Y_MAX, Math.ceil(maxR / Y_STEP) * Y_STEP)

    const sx = t => padding.left + (iw * (t - minT)) / (maxT - minT || 1)
    const sy = r => padding.top + ih - (ih * (r - yMin)) / (yMax - yMin || 1)

    // Axes (simple ticks)
    const axis = document.createElementNS(SVG_NS, "g")
    axis.style.stroke = "var(--chart-axis)"
    axis.setAttribute("stroke-width", "1")
    // X axis
    axis.appendChild(this._line(padding.left, padding.top + ih, padding.left + iw, padding.top + ih))
    // Y axis
    axis.appendChild(this._line(padding.left, padding.top, padding.left, padding.top + ih))
    svg.appendChild(axis)

    // Draw ticks and labels
    const locale = this._detectLocale()
    this._drawXTicks(svg, { padding, iw, ih, minT, maxT, sx, locale })
    this._drawYTicks(svg, { padding, ih, yMin, yMax, sy })

    // Themes can set the first series color through the --chart-primary token
    const primary = getComputedStyle(this.element).getPropertyValue("--chart-primary").trim()
    const colors = [
      primary || "#1f77b4",
      "#ff7f0e",
      "#2ca02c",
      "#d62728",
      "#9467bd",
      "#8c564b"
    ]

    // Balance-patch resets, behind the curves
    allResets.forEach(reset => {
      const x = sx(reset.t)
      const bar = this._line(x, padding.top, x, padding.top + ih)
      bar.setAttribute("stroke", RESET_COLOR)
      bar.setAttribute("stroke-width", "3")
      bar.setAttribute("opacity", "0.9")
      svg.appendChild(bar)
    })

    series.forEach((s, idx) => {
      const points = [...(s.points || [])]
      // Extend flat to now so the line reaches present
      if (points.length) {
        const last = points[points.length - 1]
        if (last.t < now) points.push({ ...last, t: now })
      }
      if (!points.length) return
      const color = colors[idx % colors.length]

      // Uncertainty band: r - k·rd .. r + k·rd
      const k = s.band_factor || 1
      if (points.every(p => p.rd != null)) {
        const upper = points.map(p => `${sx(p.t)} ${sy(p.r + k * p.rd)}`)
        const lower = points.slice().reverse().map(p => `${sx(p.t)} ${sy(p.r - k * p.rd)}`)
        const band = document.createElementNS(SVG_NS, "path")
        band.setAttribute("d", `M ${upper.join(" L ")} L ${lower.join(" L ")} Z`)
        band.setAttribute("fill", color)
        band.setAttribute("fill-opacity", "0.15")
        band.setAttribute("stroke", "none")
        svg.appendChild(band)
      }

      const path = document.createElementNS(SVG_NS, "path")
      // Straight line segments
      let d = ""
      points.forEach((p, i) => {
        d += i === 0 ? `M ${sx(p.t)} ${sy(p.r)}` : ` L ${sx(p.t)} ${sy(p.r)}`
      })
      path.setAttribute("d", d)
      path.setAttribute("fill", "none")
      path.setAttribute("stroke", color)
      path.setAttribute("stroke-width", "2")
      path.setAttribute("stroke-linecap", "round")
      path.setAttribute("stroke-linejoin", "round")
      svg.appendChild(path)

      // Label last point
      const last = points[points.length - 1]
      const maxX = padding.left + iw - 2
      const tx = Math.min(sx(last.t) + 6, maxX)
      const ty = sy(last.r)
      const label = document.createElementNS(SVG_NS, "text")
      label.setAttribute("x", tx)
      label.setAttribute("y", ty)
      label.setAttribute("fill", color)
      label.setAttribute("font-size", "12")
      label.textContent = s.name
      svg.appendChild(label)
    })
  }

  _line(x1, y1, x2, y2) {
    const el = document.createElementNS("http://www.w3.org/2000/svg", "line")
    el.setAttribute("x1", x1)
    el.setAttribute("y1", y1)
    el.setAttribute("x2", x2)
    el.setAttribute("y2", y2)
    return el
  }

  _drawXTicks(svg, { padding, iw, ih, minT, maxT, sx, locale }) {
    const group = document.createElementNS("http://www.w3.org/2000/svg", "g")
    group.style.stroke = "var(--chart-grid)"
    group.setAttribute("stroke-width", "1")

    const ticks = 5
    const step = (maxT - minT) / ticks
    for (let i = 0; i <= ticks; i++) {
      const t = minT + i * step
      const x = sx(t)
      // grid line
      const grid = this._line(x, padding.top, x, padding.top + ih)
      grid.setAttribute("opacity", "0.6")
      group.appendChild(grid)

      // label
      const label = document.createElementNS("http://www.w3.org/2000/svg", "text")
      label.setAttribute("x", x)
      label.setAttribute("y", padding.top + ih + 14)
      label.setAttribute("fill", "currentColor")
      label.setAttribute("font-size", "15")
      label.setAttribute("text-anchor", "middle")
      label.textContent = this._formatDate(t, locale)
      group.appendChild(label)
    }

    svg.appendChild(group)
  }

  _drawYTicks(svg, { padding, ih, yMin, yMax, sy }) {
    const group = document.createElementNS("http://www.w3.org/2000/svg", "g")
    group.style.stroke = "var(--chart-grid)"
    group.setAttribute("stroke-width", "1")

    for (let r = yMin; r <= yMax; r += Y_STEP) {
      const y = sy(r)
      // grid line, emphasised at the 1500 midpoint
      const grid = this._line(padding.left, y, padding.left + (svg.viewBox.baseVal.width - padding.right), y)
      if (r === Y_MID) {
        grid.style.stroke = "var(--chart-axis)"
        grid.setAttribute("stroke-dasharray", "4 3")
      } else {
        grid.setAttribute("opacity", "0.6")
      }
      group.appendChild(grid)

      // label
      const label = document.createElementNS("http://www.w3.org/2000/svg", "text")
      label.setAttribute("x", padding.left - 6)
      label.setAttribute("y", y + 3)
      label.setAttribute("fill", "currentColor")
      label.setAttribute("font-size", "15")
      label.setAttribute("text-anchor", "end")
      label.textContent = Math.round(r)
      group.appendChild(label)
    }

    svg.appendChild(group)
  }

  _formatDate(ts, locale) {
    const d = new Date(ts)
    try {
      return d.toLocaleDateString(locale || undefined, { year: 'numeric', month: 'short', day: '2-digit' })
    } catch (e) {
      return d.toISOString().slice(0, 10)
    }
  }

  _detectLocale() {
    // Try to infer from URL /en or /fr; fallback to document/document language
    const path = window.location.pathname || ''
    const seg = path.split('/')[1]
    if (seg === 'en' || seg === 'fr') return seg
    return document.documentElement.lang || navigator.language || 'en'
  }
}
