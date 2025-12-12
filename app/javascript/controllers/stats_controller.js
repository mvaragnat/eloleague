import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "system",
    "faction",
    "factionsTable",
    "versusTable",
    "chart"
  ]

  connect() {
    this._factionsSort = { key: "win_percent", dir: "desc" }
    this._vsSort = { key: "games", dir: "desc" }
    this._factionOptions = []
  }

  async onSystemChange() {
    const systemId = this.systemTarget.value
    // Reset faction select and views
    this.factionTarget.innerHTML = `<option value="">${this._t('stats.select_faction', 'Select a faction')}</option>`
    this.factionTarget.disabled = !systemId
    // Hide wrappers, not inner elements
    this._setHidden(this.factionsTableTarget.closest('#factions-table'), true)
    this._setHidden(this.chartTarget?.closest('#faction-graph'), true)
    this._setHidden(this.versusTableTarget.closest('#versus-table'), true)
    // Ensure inner elements are not stuck hidden from a previous state
    this.factionsTableTarget.hidden = false
    if (this.chartTarget) this.chartTarget.hidden = false
    if (!systemId) return

    await this._loadFactionsTable(systemId)
    await this._loadFactionOptions(systemId)
  }

  async onFactionChange() {
    const factionId = this.factionTarget.value
    this._setHidden(this.chartTarget?.closest('#faction-graph'), true)
    this._setHidden(this.versusTableTarget.closest('#versus-table'), true)
    if (!factionId) return

    await Promise.all([
      this._loadFactionSeries(factionId),
      this._loadVersusTable(factionId)
    ])
  }

  sort(ev) { this._sortTable(ev, this.factionsTableTarget, '_factionsData', this._factionsSort) }
  sortVs(ev) { this._sortTable(ev, this.versusTableTarget, '_vsData', this._vsSort) }

  async _loadFactionsTable(systemId) {
    const url = this._url(`/stats/factions?game_system_id=${encodeURIComponent(systemId)}`)
    const res = await fetch(url, { headers: { 'Accept': 'application/json' } })
    const data = await res.json()
    this._factionsData = data.rows || []
    this._renderRows(this.factionsTableTarget, this._factionsData, row => `
      <tr data-faction-id="${row.faction_id}">
        <td>${this._e(row.faction_name)}</td>
        <td>${row.total_games}</td>
        <td>${row.unique_players}</td>
        <td>${row.wins}</td>
        <td>${row.losses}</td>
        <td>${row.draws}</td>
        <td>${row.win_percent?.toFixed(2)}%</td>
        <td>${row.draw_percent?.toFixed(2)}%</td>
      </tr>
    `)
    // Show both wrapper and table
    const wrapper = this.factionsTableTarget.closest('#factions-table')
    this._setHidden(wrapper, false)
    this.factionsTableTarget.hidden = false
  }

  async _loadFactionOptions(systemId) {
    const url = this._url(`/game/factions?game_system_id=${encodeURIComponent(systemId)}`)
    const res = await fetch(url, { headers: { 'Accept': 'application/json' } })
    const list = await res.json()
    this._factionOptions = list
    for (const f of list) {
      const opt = document.createElement('option')
      opt.value = String(f.id)
      opt.textContent = f.name
      this.factionTarget.appendChild(opt)
    }
  }

  async _loadFactionSeries(factionId) {
    const url = this._url(`/stats/faction_winrate_series?faction_id=${encodeURIComponent(factionId)}`)
    const res = await fetch(url, { headers: { 'Accept': 'application/json' } })
    const data = await res.json()
    const series = data.series || []
    // Update the elo-chart controller value directly to avoid timing issues
    const ctrl = this.application.getControllerForElementAndIdentifier(this.chartTarget, 'elo-chart')
    if (ctrl) {
      ctrl.seriesValue = series
      if (ctrl.render) ctrl.render()
    } else {
      // Fallback: set dataset so when controller connects it renders
      this.chartTarget.dataset.eloChartSeriesValue = JSON.stringify(series)
    }
    // Show both wrapper and svg
    this._setHidden(this.chartTarget.closest('#faction-graph'), false)
    this.chartTarget.hidden = false
  }

  async _loadVersusTable(factionId) {
    const url = this._url(`/stats/faction_vs?faction_id=${encodeURIComponent(factionId)}`)
    const res = await fetch(url, { headers: { 'Accept': 'application/json' } })
    const data = await res.json()
    this._vsData = data.rows || []
    this._renderRows(this.versusTableTarget, this._vsData, row => `
      <tr>
        <td>${this._e(row.opponent_faction_name)}</td>
        <td>${row.games}</td>
        <td>${row.unique_players}</td>
        <td>${row.wins}</td>
        <td>${row.losses}</td>
        <td>${row.draws}</td>
        <td>${row.draw_percent == null ? '' : (row.draw_percent.toFixed(2) + '%')}</td>
        <td>${row.win_percent == null ? '' : (row.win_percent.toFixed(2) + '%')}</td>
        <td>${row.mirror_count}</td>
      </tr>
    `)
    this._setHidden(this.versusTableTarget.closest('#versus-table'), false)
  }

  _renderRows(tableEl, rows, templateFn) {
    const tbody = tableEl.querySelector('tbody')
    tbody.innerHTML = rows.map(templateFn).join('')
  }

  _sortTable(ev, tableEl, dataKey, state) {
    const th = ev.currentTarget
    const key = th.dataset.key
    if (!key) return
    if (state.key === key) {
      state.dir = state.dir === 'asc' ? 'desc' : 'asc'
    } else {
      state.key = key
      state.dir = 'asc'
    }
    // Update header visual states
    tableEl.querySelectorAll('th.sortable').forEach(h => { h.classList.remove('is-sorted'); h.removeAttribute('aria-sort') })
    th.classList.add('is-sorted')
    th.setAttribute('aria-sort', state.dir === 'asc' ? 'ascending' : 'descending')
    const data = this[dataKey] || []
    data.sort((a, b) => {
      const va = a[key]
      const vb = b[key]
      if (va == null && vb != null) return 1
      if (va != null && vb == null) return -1
      if (va == null && vb == null) return 0
      if (typeof va === 'string') {
        return state.dir === 'asc' ? va.localeCompare(vb) : vb.localeCompare(va)
      }
      return state.dir === 'asc' ? (va - vb) : (vb - va)
    })
    this._renderRows(tableEl, data, row => {
      if (dataKey === '_factionsData') {
        return `
          <tr data-faction-id="${row.faction_id}">
            <td>${this._e(row.faction_name)}</td>
            <td>${row.total_games}</td>
            <td>${row.unique_players}</td>
            <td>${row.wins}</td>
            <td>${row.losses}</td>
            <td>${row.draws}</td>
            <td>${row.draw_percent?.toFixed(2)}%</td>
            <td>${row.win_percent?.toFixed(2)}%</td>
          </tr>
        `
      }
      return `
        <tr>
          <td>${this._e(row.opponent_faction_name)}</td>
          <td>${row.games}</td>
          <td>${row.unique_players}</td>
          <td>${row.wins}</td>
          <td>${row.losses}</td>
          <td>${row.draws}</td>
          <td>${row.draw_percent == null ? '' : (row.draw_percent.toFixed(2) + '%')}</td>
          <td>${row.win_percent == null ? '' : (row.win_percent.toFixed(2) + '%')}</td>
          <td>${row.mirror_count}</td>
        </tr>
      `
    })
  }

  _setHidden(el, hidden) { if (el) el.hidden = hidden }
  _e(str) { return (str || '').replace(/[&<>"']/g, s => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','\'':'&#39;'}[s])) }
  _url(path) { return (document.querySelector('html').getAttribute('lang') ? `/${document.querySelector('html').getAttribute('lang')}` : '') + path }
  _t(key, fallback) { try { return window.I18n?.t ? window.I18n.t(key) : fallback } catch(_) { return fallback } }
}


