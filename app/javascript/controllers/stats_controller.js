import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "system",
    "faction",
    "factionsTable",
    "versusTable",
    "versusTableWrapper",
    "versusEmpty",
    "topPlayers",
    "topPlayersTable",
    "chart",
    "hideHighConcentration",
    "hideHighUncertainty",
    "tournamentOnly",
    "factionGames"
  ]

  connect() {
    // Factions default to the rating R, best first
    this._factionsSort = { key: "rating", dir: "desc" }
    this._vsSort = { key: "games", dir: "desc" }
    this._factionOptions = []
    this._lastTournamentOnly = this._tournamentOnlyEnabled()

    if (this.systemTarget.value) {
      this.onSystemChange()
    }
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
    this._setHidden(this.topPlayersTarget, true)
    this._setHidden(this.factionGamesTarget, true)
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
    this._setHidden(this.topPlayersTarget, true)
    this._setHidden(this.versusTableTarget.closest('#versus-table'), true)
    this._setHidden(this.factionGamesTarget, true)
    if (!factionId) return

    await Promise.all([
      this._loadFactionSeries(factionId),
      this._loadTopPlayers(factionId),
      this._loadVersusTable(factionId),
      this._loadFactionGames(factionId)
    ])
  }

  async onFiltersChange() {
    this._applyFactionFilters()

    const tournamentOnly = this._tournamentOnlyEnabled()
    const tournamentOnlyChanged = tournamentOnly !== this._lastTournamentOnly
    this._lastTournamentOnly = tournamentOnly
    if (!tournamentOnlyChanged) return

    const systemId = this.systemTarget.value
    if (!systemId) return

    await this._loadFactionsTable(systemId)

    const factionId = this.factionTarget.value
    if (!factionId) return

    // The rating chart uses every competitive game and ignores the tournament-only filter
    await Promise.all([
      this._loadTopPlayers(factionId),
      this._loadVersusTable(factionId),
      this._loadFactionGames(factionId)
    ])
  }

  sort(ev) { this._sortTable(ev, this.factionsTableTarget, '_factionsData', this._factionsSort) }
  sortVs(ev) { this._sortTable(ev, this.versusTableTarget, '_vsData', this._vsSort) }

  async _loadFactionsTable(systemId) {
    const url = this._url(this._withStatsFilters(`/stats/factions?game_system_id=${encodeURIComponent(systemId)}`))
    const res = await fetch(url, { headers: { 'Accept': 'application/json' } })
    const data = await res.json()
    this._factionsData = this._sortData(this._normalizeRows(data.rows || []), this._factionsSort)
    this._markSortedHeader(this.factionsTableTarget, this._factionsSort)
    this._renderRows(this.factionsTableTarget, this._factionsData, row => this._factionRow(row))
    // Show both wrapper and table
    const wrapper = this.factionsTableTarget.closest('#factions-table')
    this._setHidden(wrapper, false)
    this.factionsTableTarget.hidden = false
  }

  _factionRow(row) {
    return `
      <tr data-faction-id="${row.faction_id}" data-high-concentration="${row.high_concentration}" data-high-uncertainty="${row.provisional}">
        <td>${this._e(row.faction_name)}</td>
        ${this._ratingCells(row)}
        ${this._concentrationCell(row)}
        <td>${row.total_games}</td>
        <td>${row.unique_players}</td>
        <td>${row.wins}</td>
        <td>${row.losses}</td>
        <td>${row.draws}</td>
        <td>${row.win_percent != null ? row.win_percent + '%' : ''}</td>
        <td>${row.loss_percent != null ? row.loss_percent + '%' : ''}</td>
        <td>${row.draw_percent != null ? row.draw_percent + '%' : ''}</td>
        ${this._diffCell(row.win_loss_diff)}
      </tr>
    `
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
    const url = this._url(`/stats/faction_rating_series?faction_id=${encodeURIComponent(factionId)}`)
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
    const url = this._url(this._withStatsFilters(`/stats/faction_vs?faction_id=${encodeURIComponent(factionId)}`))
    const res = await fetch(url, { headers: { 'Accept': 'application/json' } })
    const data = await res.json()
    this._vsData = this._normalizeRows(data.rows || [])

    if (this._vsData.length > 0) {
      this._renderRows(this.versusTableTarget, this._vsData, row => `
        <tr data-has-warning="${row.has_warning}">
          <td>${this._e(row.opponent_faction_name)}</td>
          <td>${row.games}</td>
          <td>${row.unique_players}</td>
          <td>${row.wins}</td>
          <td>${row.losses}</td>
          <td>${row.draws}</td>
          <td>${row.win_percent != null ? row.win_percent + '%' : ''}</td>
          <td>${row.loss_percent != null ? row.loss_percent + '%' : ''}</td>
          <td>${row.draw_percent != null ? row.draw_percent + '%' : ''}</td>
          ${this._diffCell(row.win_loss_diff)}
          <td>${row.mirror_count}</td>
          <td>${this._e(row.warning_text)}</td>
        </tr>
      `)
    }
    this._updateVersusVisibility()
    this._setHidden(this.versusTableTarget.closest('#versus-table'), false)
  }

  async _loadTopPlayers(factionId) {
    const url = this._url(this._withStatsFilters(`/stats/faction_top_players?faction_id=${encodeURIComponent(factionId)}`))
    const res = await fetch(url, { headers: { 'Accept': 'application/json' } })
    const data = await res.json()
    const players = data.players || []
    const tbody = this.topPlayersTableTarget.querySelector('tbody')
    if (players.length === 0) {
      tbody.innerHTML = ''
      this._setHidden(this.topPlayersTarget, true)
      return
    }
    tbody.innerHTML = players.map((p, i) => `
      <tr>
        <td>${i + 1}</td>
        <td>${p.profile_url ? `<a href="${this._e(p.profile_url)}">${this._e(p.username)}</a>` : this._e(p.username)}</td>
        <td>${p.games_count}</td>
        <td>${p.win_percent != null ? p.win_percent + '%' : ''}</td>
        <td>${p.loss_percent != null ? p.loss_percent + '%' : ''}</td>
        <td>${p.draw_percent != null ? p.draw_percent + '%' : ''}</td>
      </tr>
    `).join('')
    this._setHidden(this.topPlayersTarget, false)
  }

  async _loadFactionGames(factionId) {
    const url = this._url(this._withStatsFilters(`/stats/faction_games?faction_id=${encodeURIComponent(factionId)}`))
    const res = await fetch(url, { headers: { 'Accept': 'text/html' } })
    const html = await res.text()
    const frame = this.factionGamesTarget.querySelector('#faction-games-frame')
    if (frame) frame.innerHTML = html
    this._setHidden(this.factionGamesTarget, false)
  }

  _renderRows(tableEl, rows, templateFn) {
    const tbody = tableEl.querySelector('tbody')
    tbody.innerHTML = rows.map(templateFn).join('')
    if (tableEl === this.factionsTableTarget) this._applyFactionFilters()
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
    this._markSortedHeader(tableEl, state)
    const data = this._sortData(this[dataKey] || [], state)
    this._renderRows(tableEl, data, row => {
      if (dataKey === '_factionsData') return this._factionRow(row)
      return `
        <tr data-has-warning="${row.has_warning}">
          <td>${this._e(row.opponent_faction_name)}</td>
          <td>${row.games}</td>
          <td>${row.unique_players}</td>
          <td>${row.wins}</td>
          <td>${row.losses}</td>
          <td>${row.draws}</td>
          <td>${row.win_percent != null ? row.win_percent + '%' : ''}</td>
          <td>${row.loss_percent != null ? row.loss_percent + '%' : ''}</td>
          <td>${row.draw_percent != null ? row.draw_percent + '%' : ''}</td>
          ${this._diffCell(row.win_loss_diff)}
          <td>${row.mirror_count}</td>
          <td>${this._e(row.warning_text)}</td>
        </tr>
      `
    })
  }

  _sortData(data, { key, dir }) {
    return data.sort((a, b) => {
      const va = a[key]
      const vb = b[key]
      if (va == null && vb != null) return 1
      if (va != null && vb == null) return -1
      if (va == null && vb == null) return 0
      if (typeof va === 'string') {
        return dir === 'asc' ? va.localeCompare(vb) : vb.localeCompare(va)
      }
      return dir === 'asc' ? (va - vb) : (vb - va)
    })
  }

  _markSortedHeader(tableEl, { key, dir }) {
    tableEl.querySelectorAll('th.sortable').forEach(h => {
      const sorted = h.dataset.key === key
      h.classList.toggle('is-sorted', sorted)
      if (sorted) {
        h.setAttribute('aria-sort', dir === 'asc' ? 'ascending' : 'descending')
      } else {
        h.removeAttribute('aria-sort')
      }
    })
  }

  _normalizeRows(rows) {
    return rows.map(row => {
      const warnings = Array.isArray(row.warnings) ? row.warnings : []
      const wp = row.win_percent != null ? Math.round(row.win_percent) : null
      const lp = row.loss_percent != null ? Math.round(row.loss_percent) : null
      const dp = row.draw_percent != null ? Math.round(row.draw_percent) : null
      const wld = (wp != null && lp != null) ? (wp - lp) : null
      return {
        ...row,
        win_percent: wp,
        loss_percent: lp,
        draw_percent: dp,
        win_loss_diff: wld,
        warnings,
        has_warning: warnings.length > 0,
        warning_text: warnings.join(" | ")
      }
    })
  }

  // Hide factions flagged with the "high concentration" and/or "high uncertainty" badges
  _applyFactionFilters() {
    const hideConcentration = this.hasHideHighConcentrationTarget && this.hideHighConcentrationTarget.checked
    const hideUncertainty = this.hasHideHighUncertaintyTarget && this.hideHighUncertaintyTarget.checked
    this.factionsTableTarget.querySelectorAll('tbody tr').forEach(row => {
      row.hidden = (hideConcentration && row.dataset.highConcentration === 'true') ||
        (hideUncertainty && row.dataset.highUncertainty === 'true')
    })
  }

  _updateVersusVisibility() {
    const rows = this.versusTableTarget.querySelectorAll('tbody tr')
    const hasVisibleRows = Array.from(rows).some(r => !r.hidden)
    this._setHidden(this.versusTableWrapperTarget, !hasVisibleRows)
    this._setHidden(this.versusEmptyTarget, hasVisibleRows)
  }

  _tournamentOnlyEnabled() {
    return this.tournamentOnlyTarget ? this.tournamentOnlyTarget.checked : false
  }

  _withStatsFilters(path) {
    const url = new URL(path, window.location.origin)
    if (this._tournamentOnlyEnabled()) {
      url.searchParams.set('tournament_only', '1')
    } else {
      url.searchParams.delete('tournament_only')
    }
    return `${url.pathname}${url.search}`
  }

  _diffCell(val) {
    if (val == null) return '<td></td>'
    const abs = Math.abs(val)
    const cls = abs > 15 ? ' class="text-red"' : ''
    const sign = val > 0 ? '+' : ''
    return `<td${cls}>${sign}${val}%</td>`
  }

  // Rating R, then its uncertainty RD with the "high uncertainty" badge
  _ratingCells(row) {
    if (row.rating == null) return '<td></td><td></td>'
    const badge = row.provisional ? ` ${this._badge(this._provisionalLabel())}` : ''
    return `<td>${row.rating}</td><td>${row.rating_deviation}${badge}</td>`
  }


  // Concentration of the faction's recent games among players (Herfindahl index)
  _concentrationCell(row) {
    if (row.concentration == null) return '<td></td>'
    const badge = row.high_concentration
      ? ` ${this._badge(this.element.dataset.highConcentrationLabel, 'concentration')}`
      : ''
    return `<td>${Math.round(row.concentration * 100)}%${badge}</td>`
  }

  _badge(label, kind = 'provisional') {
    return `<span class="status-badge status-badge--${kind}">${this._e(label)}</span>`
  }

  _provisionalLabel() {
    return this.element.dataset.provisionalLabel || 'Provisional'
  }

  _setHidden(el, hidden) { if (el) el.hidden = hidden }
  _e(str) { return (str || '').replace(/[&<>"']/g, s => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','\'':'&#39;'}[s])) }
  _url(path) { return (document.querySelector('html').getAttribute('lang') ? `/${document.querySelector('html').getAttribute('lang')}` : '') + path }
  _t(key, fallback) { try { return window.I18n?.t ? window.I18n.t(key) : fallback } catch(_) { return fallback } }
}


