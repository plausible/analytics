defmodule Plausible.Stats.Query.Test do
  @moduledoc false

  @date_key :__date
  @now_key :__now
  @query_set_key :query_set
  @query_include_key :query_set_include

  def date_key, do: @date_key
  def now_key, do: @now_key

  def fix_date(date) do
    Process.put(@date_key, date)
  end

  def get_fixed_date() do
    Process.get(@date_key)
  end

  def get_fixed_now() do
    Process.get(@now_key)
  end

  def fix_query(conn, payload) do
    Plug.Conn.put_private(conn, @query_set_key, payload)
  end

  def fix_query_include(conn, payload) do
    Plug.Conn.put_private(conn, @query_include_key, payload)
  end

  def get_fixed_query_overrides(conn) do
    %{
      @query_set_key => conn.private[@query_set_key],
      @query_include_key => conn.private[@query_include_key] || %{}
    }
  end

  def get_fixed_query_set(overrides) do
    Map.get(overrides, @query_set_key, %{})
  end

  def get_fixed_query_include(overrides) do
    Map.get(overrides, @query_include_key, %{})
  end
end
