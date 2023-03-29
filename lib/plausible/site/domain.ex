defmodule Plausible.Site.Domain do
  @expire_threshold_hours 72

  @moduledoc """
  Basic interface for domain changes.

  Once V2 schema migration is ready, domain change operation
  will be enabled, accessible to the users.

  We will set a grace period of #{@expire_threshold_hours} hours
  during which both old and new domains will redirect events traffic
  to the same site. A periodic worker will call the `expire/0` 
  function to end it where applicable.
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
  def change(site = %Site{}, new_domain, opts \\ []) when is_binary(new_domain) do
    changeset = Site.update_changeset(site, %{domain: new_domain}, opts)

    changeset =
      if Enum.empty?(changeset.changes) do
        Ecto.Changeset.add_error(
          changeset,
          :domain,
          "New domain must be different than your current one."
        )
      else
        changeset
      end

    Repo.update(changeset)
  end
end
