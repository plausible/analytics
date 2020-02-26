defmodule Plausible.Repo.Migrations.BackfillFingerprints do
  use Ecto.Migration

  def change do
    execute "UPDATE events set fingerprint=user_id where fingerprint is null"

    execute """
    INSERT INTO fingerprint_sessions (hostname, domain, fingerprint, start, length, is_bounce, entry_page, exit_page, referrer, referrer_source, country_code, screen_size, operating_system, browser, timestamp)
    SELECT hostname, domain, user_id, start, length, is_bounce, entry_page, exit_page, referrer, referrer_source, country_code, screen_size, operating_system, browser, timestamp
      FROM sessions
      WHERE sessions.timestamp < '2020-02-27 11:40:55';
    """
  end
end
