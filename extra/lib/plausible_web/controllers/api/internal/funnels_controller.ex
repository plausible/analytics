defmodule PlausibleWeb.Api.Internal.FunnelsController do
  @moduledoc """
  Internal API controller for managing funnels from the dashboard.
  """
  use PlausibleWeb, :controller
  use PlausibleWeb.Plugs.ErrorHandler
  use Plausible.Funnel

  alias Plausible.ChangesetHelpers
  alias Plausible.Funnels
  alias PlausibleWeb.Api.Helpers, as: H

  @manage_roles [:owner, :admin, :editor, :super_admin]

  plug :authorize_management

  def show(conn, %{"funnel_id" => funnel_id}) do
    case fetch_funnel(conn.assigns.site, funnel_id) do
      {:ok, funnel} -> json(conn, to_definition(funnel))
      error -> handle_error(conn, error)
    end
  end

  def create(conn, %{"name" => name, "steps" => steps} = params) when is_list(steps) do
    site = conn.assigns.site

    with {:ok, funnel_type} <- parse_funnel_type(conn, params),
         {:ok, funnel} <-
           Funnels.create(site, name, steps,
             funnel_type: funnel_type || Funnel.default_funnel_type()
           ) do
      json(conn, to_list_item(funnel))
    else
      error -> handle_error(conn, error)
    end
  end

  def create(conn, _params), do: H.bad_request(conn, "Invalid request")

  def update(conn, %{"funnel_id" => funnel_id} = params) do
    site = conn.assigns.site

    with {:ok, funnel} <- fetch_funnel(site, funnel_id),
         {:ok, funnel_type} <- parse_funnel_type(conn, params),
         {:ok, steps} <- parse_steps(conn, params),
         opts = if(funnel_type, do: [funnel_type: funnel_type], else: []),
         {:ok, funnel} <- Funnels.update(funnel, params["name"] || funnel.name, steps, opts) do
      json(conn, to_list_item(funnel))
    else
      error -> handle_error(conn, error)
    end
  end

  def delete(conn, %{"funnel_id" => funnel_id}) do
    site = conn.assigns.site

    case fetch_funnel(site, funnel_id) do
      {:ok, funnel} ->
        :ok = Funnels.delete(site, funnel.id)
        json(conn, to_list_item(funnel))

      error ->
        handle_error(conn, error)
    end
  end

  defp authorize_management(conn, _opts) do
    if conn.assigns[:current_user] && conn.assigns[:site_role] in @manage_roles do
      conn
    else
      H.not_enough_permissions(conn, "Not enough permissions to manage funnels")
    end
  end

  defp fetch_funnel(site, funnel_id) do
    with {id, ""} when id > 0 <- Integer.parse(funnel_id),
         %Funnel{} = funnel <- Funnels.get(site, id) do
      {:ok, funnel}
    else
      _ -> {:error, :funnel_not_found}
    end
  end

  defp parse_funnel_type(_conn, %{"funnel_type" => funnel_type}) when is_binary(funnel_type) do
    case Enum.find(Funnel.funnel_types(), &(to_string(&1) == funnel_type)) do
      nil -> {:error, :invalid_funnel_type}
      funnel_type -> {:ok, funnel_type}
    end
  end

  defp parse_funnel_type(_conn, _params), do: {:ok, nil}

  defp parse_steps(_conn, %{"steps" => steps}) when is_list(steps), do: {:ok, steps}
  defp parse_steps(_conn, %{"steps" => _}), do: {:error, :invalid_step}
  defp parse_steps(_conn, _params), do: {:ok, nil}

  defp handle_error(conn, {:error, :funnel_not_found}) do
    H.not_found(conn, "Funnel not found")
  end

  defp handle_error(conn, {:error, :upgrade_required}) do
    H.payment_required(
      conn,
      "#{Plausible.Billing.Feature.Funnels.display_name()} is part of the Plausible Business plan. To get access to this feature, please upgrade your account."
    )
  end

  defp handle_error(conn, {:error, :invalid_funnel_size}) do
    H.bad_request(
      conn,
      "A funnel must have between #{Funnel.min_steps()} and #{Funnel.max_steps()} steps"
    )
  end

  defp handle_error(conn, {:error, :invalid_funnel_type}) do
    H.bad_request(conn, "Invalid funnel type")
  end

  defp handle_error(conn, {:error, :invalid_goal}) do
    H.bad_request(conn, "One of the steps refers to a goal that doesn't exist")
  end

  defp handle_error(conn, {:error, :invalid_step}) do
    H.bad_request(conn, "One of the steps is invalid")
  end

  defp handle_error(conn, {:error, %Ecto.Changeset{} = changeset}) do
    H.bad_request(conn, first_error(changeset))
  end

  defp first_error(changeset) do
    changeset
    |> ChangesetHelpers.traverse_errors()
    |> flatten_errors()
    |> List.first("Invalid funnel")
  end

  # Errors of individual steps are nested, e.g. `%{dynamic_steps: [%{page_path: [...]}]}`
  defp flatten_errors(errors, prefix \\ nil) do
    Enum.flat_map(errors, fn {field, messages} ->
      label = if prefix, do: "#{prefix} #{field}", else: "#{field}"

      Enum.flat_map(List.wrap(messages), fn
        message when is_binary(message) -> ["#{label} #{message}"]
        nested when is_map(nested) -> flatten_errors(nested, "step")
      end)
    end)
  end

  defp to_list_item(funnel) do
    %{
      id: funnel.id,
      name: funnel.name,
      funnel_type: funnel.funnel_type,
      steps_count: length(Funnel.steps(funnel))
    }
  end

  defp to_definition(funnel) do
    steps =
      Enum.map(Funnel.steps(funnel), fn step ->
        goal = Funnel.as_goal(step)

        %{
          goal_id: if(goal.id > 0, do: goal.id),
          label: to_string(goal),
          event_name: goal.event_name,
          page_path: goal.page_path,
          scroll_threshold: goal.scroll_threshold,
          custom_props: goal.custom_props,
          currency: goal.currency,
          goal_kind: Plausible.Stats.Funnel.goal_kind(goal)
        }
      end)

    funnel
    |> to_list_item()
    |> Map.put(:steps, steps)
  end
end
