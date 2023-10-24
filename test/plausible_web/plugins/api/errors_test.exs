defmodule PlausibleWeb.Plugins.API.ErrorsTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest, only: [json_response: 2]

  alias PlausibleWeb.Plugins.API.Errors

  describe "unauthorized/1" do
    test "sends an 401 response with the `www-authenticate` header set" do
      conn =
        Plug.Test.conn(:get, "/")
        |> Errors.unauthorized()

      assert conn.halted

      assert json_response(conn, 401) == %{
               "errors" => [%{"detail" => "Plugins API: unauthorized"}]
             }

      assert Plug.Conn.get_resp_header(conn, "www-authenticate") == [
               ~s[Basic realm="Plugins API Access"]
             ]
    end
  end

  describe "error/3" do
    test "formats the given error message" do
      message = "Some message"

      conn =
        Plug.Test.conn(:get, "/")
        |> Errors.error(:forbidden, message)

      assert conn.halted

      assert json_response(conn, 403) == %{
               "errors" => [%{"detail" => "Some message"}]
             }
    end

    defmodule Example do
      use Ecto.Schema
      import Ecto.Changeset

      schema "" do
        field(:name)
        field(:email)
        field(:age, :integer)
      end

      def changeset(example, params \\ %{}) do
        example
        |> cast(params, [:name, :email, :age])
        |> validate_required([:name, :email])
        |> validate_format(:email, ~r/@/)
        |> validate_inclusion(:age, 18..100)
      end
    end

    test "formats changeset errors" do
      changeset = Example.changeset(%Example{}, %{email: "foo", age: 101})

      errors =
        Plug.Test.conn(:get, "/")
        |> Errors.error(:bad_request, changeset)
        |> json_response(400)
        |> Map.fetch!("errors")

      assert Enum.count(errors) == 3
      assert %{"detail" => "age: is invalid"} in errors
      assert %{"detail" => "email: has invalid format"} in errors
      assert %{"detail" => "name: can't be blank"} in errors
    end
  end
end
