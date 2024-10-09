defmodule Plausible.Auth.EmailVerification do
  @moduledoc """
  API for verifying emails.
  """

  import Ecto.Query, only: [from: 2]

  alias Plausible.Auth
  alias Plausible.Auth.EmailActivationCode
  alias Plausible.Repo

  require Logger

  @expiration_hours 4

  @spec any?(Auth.User.t()) :: boolean()
  def any?(user) do
    Repo.exists?(from(v in EmailActivationCode, where: v.user_id == ^user.id))
  end

  @spec issue_code(Auth.User.t(), NaiveDateTime.t()) ::
          {:ok, EmailActivationCode.t()} | {:error, :hard_bounce | :unknown_error}
  def issue_code(user, now \\ NaiveDateTime.utc_now()) do
    now = NaiveDateTime.truncate(now, :second)

    verification =
      user
      |> EmailActivationCode.new(now)
      |> Repo.insert!(
        on_conflict: [
          set: [
            issued_at: now,
            code: EmailActivationCode.generate_code()
          ]
        ],
        conflict_target: :user_id,
        returning: true
      )

    email_template = PlausibleWeb.Email.activation_email(user, verification.code)

    case Plausible.Mailer.send(email_template) do
      :ok ->
        Logger.debug(
          "E-mail verification e-mail sent. In dev environment GET /sent-emails for details."
        )

        {:ok, verification}

      error ->
        error
    end
  end

  @spec verify_code(Auth.User.t(), String.t() | non_neg_integer()) ::
          :ok | {:error, :incorrect | :expired}
  def verify_code(user, code) do
    with {:ok, verification} <- get_verification(user, code) do
      Repo.transaction(fn ->
        user
        |> Ecto.Changeset.change(email_verified: true)
        |> Repo.update!()

        Repo.delete_all(from(c in EmailActivationCode, where: c.id == ^verification.id))
      end)

      :ok
    end
  end

  defp get_verification(user, code) do
    verification = Repo.get_by(EmailActivationCode, user_id: user.id, code: code)

    cond do
      is_nil(verification) ->
        {:error, :incorrect}

      expired?(verification) ->
        {:error, :expired}

      true ->
        {:ok, verification}
    end
  end

  @spec expired?(EmailActivationCode.t()) :: boolean()
  def expired?(verification) do
    expiration_time = NaiveDateTime.shift(NaiveDateTime.utc_now(), hour: -1 * @expiration_hours)
    NaiveDateTime.before?(verification.issued_at, expiration_time)
  end
end
