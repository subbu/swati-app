defmodule Swati.Test.RazorpayClientStub do
  @behaviour Swati.Billing.Razorpay.Client

  @impl true
  def request(opts) do
    case Process.get(:razorpay_stub) || Application.get_env(:swati, :razorpay_stub) do
      nil -> {:error, :missing_stub}
      fun when is_function(fun, 1) -> fun.(opts)
      responses when is_map(responses) -> respond_from_map(responses, opts)
    end
  end

  def stub(fun) when is_function(fun, 1) do
    Process.put(:razorpay_stub, fun)
    :ok
  end

  def stub(responses) when is_map(responses) do
    Process.put(:razorpay_stub, responses)
    :ok
  end

  def clear do
    Process.delete(:razorpay_stub)
    :ok
  end

  defp respond_from_map(responses, opts) do
    key = {opts[:method], opts[:url]}

    case Map.fetch(responses, key) do
      {:ok, response} -> response
      :error -> {:error, :missing_stub}
    end
  end
end
