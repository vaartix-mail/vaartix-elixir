defmodule Vaartix.WebhookTest do
  use ExUnit.Case, async: true
  alias Vaartix.Webhook

  # Test-only secret: the worked example from the Standard Webhooks specification.
  @prefix "whsec_"
  @secret @prefix <> "MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw"
  @body ~s({"test": 2432232314})
  @now 1_614_265_330

  defp headers do
    [
      {"webhook-id", "msg_p5jXN8AQM9LWM0D4loKWxJek"},
      {"webhook-timestamp", "1614265330"},
      {"webhook-signature", "v1,g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OE="}
    ]
  end

  test "accepts the reference example, any header case, several signatures" do
    assert {:ok, %{"test" => 2_432_232_314}} = Webhook.verify(@body, headers(), @secret, now: @now)
    upper = Enum.map(headers(), fn {k, v} -> {String.upcase(k), v} end)
    assert {:ok, _} = Webhook.verify(@body, Map.new(upper), @secret, now: @now)

    multi =
      List.keyreplace(
        headers(),
        "webhook-signature",
        0,
        {"webhook-signature", "v1,bm90LXRoaXM= v1,g0hM9SsE+OTPJTGt/tmIKtSyZlE3uFJELVlNIOLJ1OE="}
      )

    assert {:ok, _} = Webhook.verify(@body, multi, @secret, now: @now)
  end

  test "rejects" do
    assert {:error, "The webhook signature does not match."} =
             Webhook.verify(~s({"test": 1}), headers(), @secret, now: @now)

    assert {:error, "The webhook signature does not match."} =
             Webhook.verify(@body, headers(), @prefix <> "c2VjcmV0", now: @now)

    assert {:error, "The webhook timestamp is too old or in the future."} =
             Webhook.verify(@body, headers(), @secret, now: @now + 600)

    assert {:error, "Missing" <> _} = Webhook.verify(@body, [], @secret, now: @now)

    assert {:error, "The secret should start with whsec_."} =
             Webhook.verify(@body, headers(), "nope", now: @now)
  end

  test "parses a signed bounce" do
    body =
      ~s({"type":"email.bounced","data":{"recipient":"old@example.com","details":{"bounceType":"Permanent","diagnosticCode":"550 5.1.1 user unknown"}}})

    secret = @prefix <> Base.encode64("0123456789abcdef0123456789abcdef")
    key = Base.decode64!(String.replace_prefix(secret, @prefix, ""))
    sig = Base.encode64(:crypto.mac(:hmac, :sha256, key, "whd_1.#{@now}.#{body}"))
    h = [{"webhook-id", "whd_1"}, {"webhook-timestamp", "#{@now}"}, {"webhook-signature", "v1," <> sig}]
    assert {:ok, event} = Webhook.verify(body, h, secret, now: @now)
    assert event["type"] in Webhook.events()
    assert event["data"]["details"]["diagnosticCode"] == "550 5.1.1 user unknown"
  end
end
