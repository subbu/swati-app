defmodule SwatiWeb.IntegrationView do
  alias Swati.Integrations.Serialization

  def public_json(integration) do
    Serialization.public_payload(integration)
  end
end
