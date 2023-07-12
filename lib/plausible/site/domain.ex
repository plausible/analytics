defmodule Plausible.Site.Domain do
  @expire_threshold_hours 72

  @moduledoc """
  Basic interface for domain changes.

  Once `Plausible.DataMigration.NumericIDs` schema migration is ready, 
  domain change operation will be enabled, accessible to the users.

  We will set a transition period of #{@expire_threshold_hours} hours
  during which, both old and new domains, will be accepted as traffic
  identifiers to the same site. 

  A periodic worker will call the `expire/0` function to end it where applicable.
  See: `Plausible.Workers.ExpireDomainChangeTransitions`.

  The underlying changeset for domain change (see: `Plausible.Site`) relies
  on database trigger installed via `Plausible.Repo.Migrations.AllowDomainChange`
  Postgres migration. The trigger checks if either `domain` or `domain_changed_from`
  exist to ensure unicity.
  """

  alias Plausible.Site
  alias Plausible.Repo

  import Ecto.Query

  @spec expire_change_transitions(integer()) :: {:ok, non_neg_integer()}
  def expire_change_transitions(expire_threshold_hours \\ @expire_threshold_hours) do
    {updated, _} =
      Repo.update_all(
        from(s in Site,
          where: s.domain_changed_at < ago(^expire_threshold_hours, "hour")
        ),
        set: [
          domain_changed_from: nil,
          domain_changed_at: nil
        ]
      )

    {:ok, updated}
  end

  @spec change(Site.t(), String.t(), Keyword.t()) ::
          {:ok, Site.t()} | {:error, Ecto.Changeset.t()}
  def change(%Site{} = site, new_domain, opts \\ []) do
    changeset = Site.update_changeset(site, %{domain: new_domain}, opts)

    changeset =
      if is_nil(changeset.errors[:domain]) and is_nil(changeset.changes[:domain]) do
        Ecto.Changeset.add_error(
          changeset,
          :domain,
          "New domain must be different than the current one"
        )
      else
        changeset
      end

    Repo.update(changeset)
  end
end
