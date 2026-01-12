defmodule Swati.Webhooks.TesterTest do
  use Swati.DataCase

  import Swati.AccountsFixtures

  alias Swati.Webhooks

  defmodule SuccessClient do
    @behaviour Swati.Webhooks.Client

    @impl true
    def request(opts) do
      send(self(), {:webhook_request, opts})
      {:ok, %Req.Response{status: 204, body: ""}}
    end
  end

  defmodule FailureClient do
    @behaviour Swati.Webhooks.Client

    @impl true
    def request(_opts) do
      {:ok, %Req.Response{status: 500, body: "boom"}}
    end
  end

  setup do
    on_exit(fn -> Application.delete_env(:swati, :webhook_client) end)
    :ok
  end

  test "test_webhook updates status on success" do
    scope = user_scope_fixture()

    Application.put_env(:swati, :webhook_client, SuccessClient)

    attrs = %{
      "name" => "Ping",
      "endpoint_url" => "https://example.com/ping",
      "sample_payload" => "ping: true"
    }

    assert {:ok, webhook} = Webhooks.create_webhook(scope.tenant.id, attrs, scope.user)

    assert {:ok, updated} = Webhooks.test_webhook(webhook)
    assert updated.last_test_status == "success"
    assert updated.last_test_error == nil
  end

  test "test_webhook stores error on failure" do
    scope = user_scope_fixture()

    Application.put_env(:swati, :webhook_client, FailureClient)

    attrs = %{
      "name" => "Fail",
      "endpoint_url" => "https://example.com/fail",
      "sample_payload" => "payload: nope"
    }

    assert {:ok, webhook} = Webhooks.create_webhook(scope.tenant.id, attrs, scope.user)

    assert {:error, updated} = Webhooks.test_webhook(webhook)
    assert updated.last_test_status == "error"
    assert updated.last_test_error == "boom"
  end
end
