defmodule ExKikTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  doctest ExKik
  import BypassRoutes

  setup do
    bypass = Bypass.open
    :ok = Application.put_env(:ex_kik, :endpoint, "http://localhost:#{bypass.port}/")

    {:ok, bypass: bypass}
  end

  test "set webhook", %{bypass: bypass} do
    bypass_routes(bypass) do
      plug Plug.Parsers, parsers: [:json], json_decoder: Poison

      post "/config" do
        assert conn.params == %{"webhook" => "http://example.com"}
        Plug.Conn.send_resp conn, 200, ""
      end
    end

    ExKik.set_webhook("http://example.com")
  end

  test "send text", %{bypass: bypass} do
    bypass_routes(bypass) do
      plug Plug.Parsers, parsers: [:json], json_decoder: Poison

      post "/message" do
        assert conn.params == %{"messages" => [%{"body" => "Hello World", "chatId" => "foobar", "to" => "ciaran", "type" => "text", "keyboards" => []}]}
        Plug.Conn.send_resp conn, 200, ""
      end
    end

    ExKik.send_text("foobar", "ciaran", "Hello World", keyboards: [])
  end

  test "send video", %{bypass: bypass} do
    bypass_routes(bypass) do
      plug Plug.Parsers, parsers: [:json], json_decoder: Poison

      post "/message" do
        assert conn.params == %{"messages" => [%{"chatId" => "foobar", "to" => "ciaran", "type" => "text", "body" => "http://video-url.com", "attribution" => %{"name" => "ex_kik"}}]}
        Plug.Conn.send_resp conn, 200, ""
      end
    end

    ExKik.send_text("foobar", "ciaran", "http://video-url.com", attribution: %{name: "ex_kik"})
  end

  test "send manual text", %{bypass: bypass} do
    bypass_routes(bypass) do
      plug Plug.Parsers, parsers: [:json], json_decoder: Poison

      post "/message" do
        assert conn.params == %{"messages" => [%{"chatId" => "foobar", "to" => "ciaran", "type" => "text", "body" => "http://video-url.com", "attribution" => %{"name" => "ex_kik"}}]}
        Plug.Conn.send_resp conn, 200, ""
      end
    end

    message = ExKik.text_message("foobar", "ciaran", "http://video-url.com", attribution: %{name: "ex_kik"})
    ExKik.send_message(message)
  end

  test "error handling", %{bypass: bypass} do
    bypass_routes(bypass) do
      plug Plug.Parsers, parsers: [:json], json_decoder: Poison

      post "/message" do
        Plug.Conn.send_resp conn, 400, ~s({"message":"Too many requests for user: 'daisyrose82'","error":"TooManyRequests"})
      end
    end

    assert capture_log(fn ->
      message = ExKik.text_message("foobar", "ciaran", "http://video-url.com", attribution: %{name: "ex_kik"})
      ExKik.send_message(message)
    end) =~ "TooManyRequests"
  end

  def send_file(conn, file),
    do: Plug.Conn.send_resp(conn, 200, File.read!("test/fixtures/response/" <> file))
end
