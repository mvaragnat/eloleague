import { Controller } from "@hotwired/stimulus"

// A lightweight SVG chart renderer for ELO over time across multiple systems.
// Expects data via data-elo-chart-series-value: an array of
// [{ id, name, points: [{ t: epoch_ms, r: rating }, ...] }]

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
    const allPoints = series.flatMap(s => s.points)
    let minT = Math.min(...allPoints.map(p => p.t))
    let maxT = Math.max(...allPoints.map(p => p.t))
    const now = Date.now()
    if (now > maxT) maxT = now
    const minR = Math.min(...allPoints.map(p => p.r))
    const maxR = Math.max(...allPoints.map(p => p.r))

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

    // Round rating domain to nice steps (50)
    const niceStep = 50
    const yMin = Math.floor(minR / niceStep) * niceStep
    const yMax = Math.ceil(maxR / niceStep) * niceStep

    const sx = t => padding.left + (iw * (t - minT)) / (maxT - minT || 1)
    const sy = r => padding.top + ih - (ih * (r - yMin)) / (yMax - yMin || 1)

    // Axes (simple ticks)
    const axis = document.createElementNS("http://www.w3.org/2000/svg", "g")
    axis.setAttribute("stroke", "#ccc")
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

    const colors = [
      "#1f77b4", 
      "#ff7f0e", 
      "#2ca02c", 
      "#d62728", 
      "#9467bd", 
      "#8c564b"
    ]

    series.forEach((s, idx) => {
      // Apply moving average smoothing on rating values
      const original = [...(s.points || [])]
      const smoothed = this._movingAverage(original, 3)
      // Extend flat to now so the line reaches present
      if (smoothed.length) {
        const last = smoothed[smoothed.length - 1]
        if (last.t < now) smoothed.push({ t: now, r: last.r })
      }
      if (!smoothed.length) return
      const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
      const color = colors[idx % colors.length]
      const points = smoothed.map(p => ({ x: sx(p.t), y: sy(p.r) }))
      // Straight line segments
      let d = ""
      points.forEach((pt, i) => {
        d += i === 0 ? `M ${pt.x} ${pt.y}` : ` L ${pt.x} ${pt.y}`
      })
      path.setAttribute("d", d)
      path.setAttribute("fill", "none")
      path.setAttribute("stroke", color)
      path.setAttribute("stroke-width", "2")
      path.setAttribute("stroke-linecap", "round")
      path.setAttribute("stroke-linejoin", "round")
      svg.appendChild(path)

      // Label last point
      const last = smoothed[smoothed.length - 1]
      const maxX = padding.left + iw - 2
      const tx = Math.min(sx(last.t) + 6, maxX)
      const ty = sy(last.r)
      const label = document.createElementNS("http://www.w3.org/2000/svg", "text")
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
    group.setAttribute("stroke", "#e5e7eb") // light grid
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
    group.setAttribute("stroke", "#e5e7eb")
    group.setAttribute("stroke-width", "1")

    const ticks = 5
    const step = (yMax - yMin) / ticks
    for (let i = 0; i <= ticks; i++) {
      const r = yMin + i * step
      const y = sy(r)
      // grid line
      const grid = this._line(padding.left, y, padding.left + (svg.viewBox.baseVal.width - padding.right), y)
      grid.setAttribute("opacity", "0.6")
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

  // Simple moving average smoothing on rating values (window size n)
  _movingAverage(points, n = 3) {
    if (!points || points.length === 0) return []
    const out = []
    let sum = 0
    for (let i = 0; i < points.length; i++) {
      sum += points[i].r
      if (i >= n) sum -= points[i - n].r
      const count = Math.min(i + 1, n)
      out.push({ t: points[i].t, r: sum / count })
    }
    return out
  }
}


