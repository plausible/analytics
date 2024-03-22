defmodule PlausibleWeb.Plugins.API.Views.Pagination do
  @moduledoc """
  A view capable of rendering pagination metadata included
  in responses containing lists of objects.
  """
  use Phoenix.View,
    namespace: PlausibleWeb.Plugins.API,
    root: ""

  alias PlausibleWeb.Router.Helpers

  def render_metadata_links(meta, helper_fn, helper_fn_args, existing_params \\ %{}) do
    render(__MODULE__, "pagination.json", %{
      meta: meta,
      url_helper: fn query_params ->
        existing_params = Map.drop(existing_params, ["before", "after"])

        query_params =
          query_params
          |> Enum.into(%{})
          |> Map.merge(existing_params)

        args = [
          PlausibleWeb.Endpoint
          | List.wrap(helper_fn_args) ++ [query_params]
        ]

        apply(Helpers, helper_fn, args)
      end
    })
  end

  @spec render(binary(), map()) ::
          binary()
  def render("pagination.json", %{meta: meta, url_helper: url_helper_fn}) do
    pagination =
      [
        {:after, :next, :has_next_page},
        {:before, :prev, :has_prev_page}
      ]
      |> Enum.reduce(%{}, fn
        {meta_key, url_key, sibling_key}, acc ->
          meta_value = Map.get(meta, meta_key)

          if meta_value do
            url = url_helper_fn.([{meta_key, meta_value}])

            acc
            |> Map.update(
              :links,
              %{url_key => %{url: url}},
              &Map.put(&1, url_key, %{url: url})
            )
            |> Map.put(sibling_key, true)
          else
            acc
            |> Map.update(:links, %{}, & &1)
            |> Map.put(sibling_key, false)
          end
      end)

    %{
      pagination: pagination
    }
  end
end
