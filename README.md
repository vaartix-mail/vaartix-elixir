# Vaartix Elixir SDK

The official Elixir client for [Vaartix](https://vaartix.com), the transactional email API built in India.
Data stored in India (AWS Mumbai), pricing in ₹.

```elixir
def deps do
  [{:vaartix, "~> 0.1"}]
end
```

Elixir 1.15 or newer. Built on [Req](https://hexdocs.pm/req) and Jason.

## Send an email

```elixir
client = Vaartix.client()   # reads VAARTIX_API_KEY

{:ok, %{"id" => id}} =
  Vaartix.Emails.send(client, %{
    from: "Acme <orders@acme.in>",   # an address on a domain verified in Vaartix
    to: "priya@example.com",
    subject: "Your order is confirmed",
    html: "<p>Thanks for your order!</p>"
  })
```

Keys can be snake_case atoms (`reply_to`, `scheduled_at`) or the API's camelCase. Results are the API's JSON
as maps with string keys. Testing? Send to `delivered@test.vaartix.com` (or `bounced@` / `complained@`).

## Errors

Every function returns `{:ok, result}` or `{:error, %Vaartix.Error{type: ..., message: ..., status: ...}}`.
`type` is `"network_error"` (and `status` is `nil`) when no response was received.

## More sending options

```elixir
Vaartix.Emails.send(client, email, idempotency_key: "receipt-10482")             # safe retries for 24 hours
Vaartix.Emails.send(client, Map.put(email, :scheduled_at, "2026-11-15T10:00:00+05:30"))
Vaartix.Batch.send(client, [email_a, email_b])                                      # up to 100 in one request
Vaartix.Emails.send(client, Map.put(email, :tracking, %{opens: true, clicks: false}))
```

Keep click tracking off for login codes, password resets and magic links.

## Read emails

Needs a full-access key.

```elixir
Vaartix.Emails.get(client, "em_...")          # content, status and events
Vaartix.Emails.list(client, limit: 50)
Vaartix.Emails.cancel(client, "em_...")       # a scheduled email
```

## Webhooks

Check that a webhook request really came from Vaartix before you trust it. It needs the **raw** body: in
Phoenix, keep it with a body reader for the webhook route (see Plug.Parsers' `:body_reader` option).

```elixir
def create(conn, _params) do
  raw = conn.assigns[:raw_body]

  case Vaartix.Webhook.verify(raw, conn.req_headers, System.fetch_env!("VAARTIX_WEBHOOK_SECRET")) do
    {:ok, %{"type" => "email.bounced", "data" => %{"details" => details}}} ->
      _reply = details["diagnosticCode"]   # the receiving server's reply
      send_resp(conn, 200, "")

    {:ok, _event} ->
      send_resp(conn, 200, "")

    {:error, _reason} ->
      send_resp(conn, 400, "")
  end
end
```

Signatures follow the [Standard Webhooks](https://www.standardwebhooks.com) spec. Manage endpoints with
`Vaartix.Webhooks`: `create`, `list`, `get`, `update`, `remove`, `rotate_secret`, `deliveries`, `retry_delivery`.

## Domains

```elixir
Vaartix.Domains.update(client, domain_id, %{open_tracking: true})
```

## Docs

- Docs: https://vaartix.com/docs
- API reference: https://vaartix.com/docs/api
- HexDocs: https://hexdocs.pm/vaartix

## Contributing and security

Issues and pull requests are welcome. Report security problems privately, see [SECURITY.md](SECURITY.md).

## License

MIT
