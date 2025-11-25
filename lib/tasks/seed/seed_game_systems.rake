# frozen_string_literal: true

# Helper methods for seeding game systems
module SeedGameSystemsHelper
  def self.run_seeding
    config_file = Rails.root.join('config/game_systems.yml')

    Rails.logger.info 'Seeding game systems from config/game_systems.yml'

    unless File.exist?(config_file)
      Rails.logger.info "Configuration file not found: #{config_file}"
      Rails.logger.info 'Please create config/game_systems.yml with your game systems and factions'
      return
    end

    begin
      config = YAML.load_file(config_file)
      game_systems_data = config['game_systems']

      if game_systems_data.blank?
        Rails.logger.info 'No game systems found in configuration file'
        return
      end

      Rails.logger.info "Seeding game systems and factions from #{config_file}..."

      game_systems_data.each do |system_data|
        seed_game_system(system_data)
      end

      Rails.logger.info 'Seeding completed successfully!'
    rescue Psych::SyntaxError => e
      Rails.logger.info "Error parsing YAML file: #{e.message}"
    rescue StandardError => e
      Rails.logger.info "Error seeding game systems: #{e.message}"
    end
  end

  # Extract a localized value from a string or a hash of locales
  # - Prefers English ('en'), falls back to French ('fr'), then any present value
  def self.localized_value(value)
    return value if value.is_a?(String)
    return value['en'] if value.is_a?(Hash) && value['en'].present?
    return value['fr'] if value.is_a?(Hash) && value['fr'].present?

    value.is_a?(Hash) ? value.values.compact.first : nil
  end

  def self.extract_name(entry)
    case entry
    when String
      entry
    when Hash
      # Can be { 'en' => 'Name', 'fr' => 'Nom' } or { 'name' => { 'en' => 'Name', 'fr' => 'Nom' } }
      if entry.key?('name')
        localized_value(entry['name'])
      else
        localized_value(entry)
      end
    end
  end

  def self.seed_game_system(system_data)
    # Support both legacy mono-lingual strings and new localized hashes
    system_name = extract_name(system_data['name'])
    system_description = localized_value(system_data['description'])
    factions_data = system_data['factions'] || []
    scoring_systems_data = system_data['scoring_systems'] || []

    return if system_name.blank?

    # Find or create game system
    game_system = Game::System.find_by(name: system_name)

    if game_system.blank?
      game_system = Game::System.create!(
        name: system_name,
        description: system_description
      )
      Rails.logger.info "✓ Created game system: #{system_name}"
    else
      Rails.logger.info "→ Game system already exists: #{system_name}"

      # Update description if it has changed
      if game_system.description != system_description && system_description.present?
        game_system.update!(description: system_description)
        Rails.logger.info '  ↳ Updated description'
      end
    end

    # Seed factions for this game system
    seed_factions(game_system, factions_data)
    # Seed scoring systems for this game system
    seed_scoring_systems(game_system, scoring_systems_data)
  end

  def self.seed_factions(game_system, factions_data)
    return if factions_data.blank?

    factions_data.each do |faction_entry|
      faction_name = extract_name(faction_entry)
      next if faction_name.blank?

      existing_faction = game_system.factions.find_by(name: faction_name)

      if existing_faction.blank?
        game_system.factions.create!(name: faction_name)
        Rails.logger.info "  ✓ Created faction: #{faction_name}"
      else
        Rails.logger.info "  → Faction already exists: #{faction_name}"
      end
    end
  end

  def self.seed_scoring_systems(game_system, scoring_systems_data)
    return ensure_default_scoring_system(game_system) if scoring_systems_data.blank?

    upsert_scoring_systems(game_system, scoring_systems_data)
  end

  def self.ensure_default_scoring_system(game_system)
    existing_default = game_system.scoring_systems.find_by(is_default: true)
    if existing_default.blank?
      game_system.scoring_systems.create!(
        name: 'Default',
        description: nil,
        max_score_per_player: nil,
        fix_total_score: nil,
        min_difference_for_win: nil,
        is_default: true
      )
      Rails.logger.info "  ✓ Created default scoring system for #{game_system.name}"
    else
      Rails.logger.info "  → Default scoring system already exists for #{game_system.name}"
    end
  end

  def self.upsert_scoring_systems(game_system, scoring_systems_data)
    scoring_systems_data.each_with_index do |entry, idx|
      name = extract_name(entry['name'])
      next if name.blank?

      is_default = (!entry['is_default'].nil? && entry['is_default']) ||
                   (idx.zero? && game_system.scoring_systems.defaults.blank?)
      attrs = {
        description: localized_value(entry['description']),
        max_score_per_player: entry['max_score_per_player'],
        fix_total_score: entry['fix_total_score'],
        min_difference_for_win: entry['min_difference_for_win'],
        is_default: is_default
      }
      row = game_system.scoring_systems.find_or_initialize_by(name: name)
      if row.new_record?
        row.assign_attributes(attrs)
        row.save!
        Rails.logger.info "  ✓ Created scoring system: #{name}"
      else
        row.update!(attrs)
        Rails.logger.info "  → Updated scoring system: #{name}"
      end
    end
  end
end

namespace :seed do
  task game_systems: :environment do
    SeedGameSystemsHelper.run_seeding
  end
end
