defmodule VaartixTest do
  use ExUnit.Case, async: true

  defp client(status, body) do
    test_pid = self()

    plug = fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:request, %{conn | body_params: raw}})

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, body)
    end

    Vaartix.client("vx_test", base_url: "https://api.example/", req_options: [plug: plug])
  end

  defp last_request do
    assert_received {:request, conn}
    body = if conn.body_params in ["", nil], do: nil, else: Jason.decode!(conn.body_params)
    {conn, body}
  end

  defp header(conn, name), do: conn |> Plug.Conn.get_req_header(name) |> List.first()

  test "needs a key" do
    System.delete_env("VAARTIX_API_KEY")
    assert_raise ArgumentError, fn -> Vaartix.client() end
  end

  test "sends an email" do
    c = client(200, ~s({"id":"em_123"}))

    assert {:ok, %{"id" => "em_123"}} =
             Vaartix.Emails.send(
               c,
               %{
                 from: "Acme <orders@acme.in>",
                 to: "priya@example.com",
                 subject: "Hi",
                 html: "<p>Hi</p>",
                 text: nil,
                 reply_to: "help@acme.in",
                 tracking: %{opens: true}
               },
               idempotency_key: "order-1"
             )

    {req, body} = last_request()
    assert {req.method, req.request_path} == {"POST", "/emails"}
    assert header(req, "authorization") == "Bearer vx_test"
    assert header(req, "idempotency-key") == "order-1"
    assert header(req, "user-agent") == "vaartix-elixir/#{Vaartix.version()}"
    assert body["replyTo"] == "help@acme.in"
    refute Map.has_key?(body, "text")
    assert body["tracking"] == %{"opens" => true}
  end

  test "errors" do
    c = client(422, ~s({"error":{"type":"validation_error","message":"to: not a valid email address."}}))

    assert {:error, %Vaartix.Error{type: "validation_error", status: 422}} =
             Vaartix.Emails.send(c, %{to: "x"})

    c2 = client(500, "oops")
    assert {:error, %Vaartix.Error{type: "api_error", status: 500}} = Vaartix.Emails.get(c2, "em_1")

    broken =
      Vaartix.client("vx_test",
        base_url: "http://127.0.0.1:1",
        req_options: [retry: false]
      )

    assert {:error, %Vaartix.Error{type: "network_error", status: nil}} = Vaartix.Emails.get(broken, "em_1")
  end

  test "read, list, cancel" do
    c = client(200, ~s({"id":"em_1","status":"delivered"}))
    assert {:ok, %{"status" => "delivered"}} = Vaartix.Emails.get(c, "em_1/x")
    {req, _} = last_request()
    assert req.request_path == "/emails/em_1%2Fx"
    Vaartix.Emails.list(c, limit: 5, before: "em_9")
    {req, _} = last_request()
    assert req.query_string == "limit=5&before=em_9"
    Vaartix.Emails.cancel(c, "em_3")
    {req, _} = last_request()
    assert {req.method, req.request_path} == {"POST", "/emails/em_3/cancel"}
  end

  test "batch and domains" do
    c = client(200, ~s({"data":[{"id":"em_a"},{"id":"em_b"}]}))

    assert {:ok, [_, _]} =
             Vaartix.Batch.send(c, [%{from: "a@acme.in", to: "x@y.in", subject: "1", text: "1"}])

    {_, body} = last_request()
    assert is_list(body)
    c2 = client(200, ~s({"id":"dom_1","openTracking":true}))
    assert {:ok, %{"openTracking" => true}} = Vaartix.Domains.update(c2, "dom_1", %{open_tracking: true})
    {req, body} = last_request()
    assert req.method == "PATCH"
    assert body == %{"openTracking" => true}
  end

  test "webhooks" do
    c = client(200, ~s({"id":"wh_1","secret":"whsec_x","data":[]}))

    assert {:ok, %{"secret" => "whsec_x"}} =
             Vaartix.Webhooks.create(c, %{url: "https://acme.in/h", events: ["email.delivered"]})

    _ = last_request()
    Vaartix.Webhooks.update(c, "wh_1", %{status: "disabled"})
    {_, body} = last_request()
    assert body == %{"status" => "disabled"}
    Vaartix.Webhooks.rotate_secret(c, "wh_1")
    {req, _} = last_request()
    assert req.request_path == "/webhooks/wh_1/rotate-secret"
    assert {:ok, []} = Vaartix.Webhooks.deliveries(c, "wh_1", limit: 10)
    {req, _} = last_request()
    assert req.query_string == "limit=10"
    Vaartix.Webhooks.retry_delivery(c, "wh_1", "whd_2")
    {req, _} = last_request()
    assert req.request_path == "/webhooks/wh_1/deliveries/whd_2/retry"
    c2 = client(204, "")
    assert {:ok, nil} = Vaartix.Webhooks.remove(c2, "wh_1")
  end
end
