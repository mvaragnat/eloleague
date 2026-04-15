# frozen_string_literal: true

require 'open3'

# rubocop:disable Metrics/BlockLength
namespace :db do
  task refresh: :environment do
    restore_database_dump!
    with_local_timezone_connection do
      reset_seed_passwords!
    end
  end

  def restore_database_dump!
    dump_file = ENV['DB_DUMP'] || 'latest.dump'
    pg_host = ENV['PGHOST'] || 'localhost'
    pg_port = ENV['PGPORT'] || 5432
    database_name = ActiveRecord::Base.connection_db_config.database
    pg_restore_bin = resolve_postgres_bin('pg_restore')

    stdout, stderr, status = Open3.capture3(
      pg_restore_bin,
      '--verbose',
      '--clean',
      '--no-acl',
      '--no-owner',
      '-h', pg_host.to_s,
      '-p', pg_port.to_s,
      '-d', database_name.to_s,
      dump_file.to_s
    )
    restore_succeeded = status.success? || ignorable_restore_failure?(stderr)
    return delete_latest_dump_file!(dump_file) if restore_succeeded

    puts stdout unless stdout.empty?
    warn stderr unless stderr.empty?
    raise "pg_restore failed with status #{status.exitstatus}"
  end

  def with_local_timezone_connection
    # Some local PostgreSQL installs reject "UTC". Switch Rails to local DB
    # timezone for this task's reconnection and cleanup queries.
    previous_timezone = ActiveRecord.default_timezone
    ActiveRecord.default_timezone = :local
    ActiveRecord::Base.connection_pool.disconnect!
    ActiveRecord::Base.establish_connection

    begin
      yield
    ensure
      ActiveRecord.default_timezone = previous_timezone
    end
  end

  def reset_seed_passwords!
    # system('rm latest.dump')
    Admin.find_each do |admin_user|
      admin_user.update(password: 'password')
    end
    User.first&.update(password: 'password')
  end

  def resolve_postgres_bin(command_name)
    env_override = ENV.fetch("#{command_name.upcase}_BIN", nil)
    return env_override if env_override.present?

    path_candidates = ENV.fetch('PATH', '').split(':').map do |path|
      File.join(path, command_name)
    end
    path_command = path_candidates.find { |path| File.executable?(path) }
    return path_command if path_command

    brew_candidates = [
      "/opt/homebrew/opt/postgresql@18/bin/#{command_name}",
      "/opt/homebrew/opt/postgresql/bin/#{command_name}",
      "/usr/local/opt/postgresql@18/bin/#{command_name}",
      "/usr/local/opt/postgresql/bin/#{command_name}"
    ]
    matched_candidate = brew_candidates.find { |path| File.executable?(path) }
    return matched_candidate if matched_candidate

    raise "#{command_name} not found. Set PG_RESTORE_BIN or add PostgreSQL bin to PATH."
  end

  def ignorable_restore_failure?(stderr)
    expected_errors = [
      'unrecognized configuration parameter "transaction_timeout"',
      'extension "pg_stat_statements" does not exist',
      'pg_stat_statements.control',
      'erreurs ignorées lors de la restauration'
    ]
    normalized_stderr = stderr.to_s
    return false if normalized_stderr.empty?

    return false unless expected_errors.all? { |error| normalized_stderr.include?(error) }

    warn 'db:refresh continuing despite known pg_restore warnings (transaction_timeout / pg_stat_statements).'
    true
  end

  def delete_latest_dump_file!(dump_file)
    return unless File.basename(dump_file.to_s) == 'latest.dump'
    return unless File.exist?(dump_file)

    File.delete(dump_file)
  end
end
# rubocop:enable Metrics/BlockLength
