defmodule Swati.UseCases.Simulator do
  import Ecto.Query, warn: false

  alias Swati.Accounts.User
  alias Swati.Agents
  alias Swati.Approvals
  alias Swati.Channels
  alias Swati.Channels.Ingestion
  alias Swati.Handoffs
  alias Swati.Repo
  alias Swati.Tenancy.Membership

  def run(tenant_id) do
    _ = ensure_agent(tenant_id)
    endpoints = ensure_channels(tenant_id)

    %{
      use_case_a: use_case_a(tenant_id, endpoints),
      use_case_b: use_case_b(tenant_id, endpoints),
      use_case_c: use_case_c(tenant_id, endpoints),
      use_case_d: use_case_d(tenant_id, endpoints),
      use_case_e: use_case_e(tenant_id, endpoints),
      use_case_f: use_case_f(tenant_id, endpoints)
    }
  end

  defp ensure_agent(tenant_id) do
    Agents.list_agents(tenant_id)
    |> Enum.find(&(&1.status == "active" and &1.published_version_id))
    |> case do
      nil -> create_default_agent(tenant_id)
      agent -> agent
    end
  end

  defp create_default_agent(tenant_id) do
    actor = fetch_actor(tenant_id)

    with %User{} <- actor,
         {:ok, agent} <- Agents.create_agent(tenant_id, %{name: "Default Agent"}, actor),
         {:ok, agent, _version} <- Agents.publish_agent(agent, actor) do
      agent
    else
      _ -> nil
    end
  end

  defp fetch_actor(tenant_id) do
    from(m in Membership,
      where: m.tenant_id == ^tenant_id,
      order_by: [asc: m.inserted_at],
      preload: [:user],
      limit: 1
    )
    |> Repo.one()
    |> case do
      nil -> nil
      membership -> membership.user
    end
  end

  defp use_case_a(tenant_id, endpoints) do
    customer_id = "cust-clinic-001"

    {:ok, payload} =
      ingest_message(
        %{
          channel_key: "whatsapp",
          endpoint_address: endpoints.whatsapp.address,
          from_address: "+15550009999",
          customer_external_id: customer_id,
          case_category: "appointment",
          case_title: "Appointment scheduling",
          session_external_id: session_id("wa"),
          direction: "inbound"
        },
        "Hi, I need an appointment for Saturday morning."
      )

    case_id = payload.case_id

    _ =
      ingest_message(
        %{
          channel_key: "instagram",
          endpoint_address: endpoints.instagram.address,
          from_address: "ig:maya",
          customer_external_id: customer_id,
          case_id: case_id,
          session_external_id: session_id("ig"),
          direction: "inbound"
        },
        "Is Dr. available earlier? Also price?"
      )

    _ =
      ingest_message(
        %{
          channel_key: "voice",
          endpoint_address: endpoints.voice.address,
          from_address: "+15550009999",
          customer_external_id: customer_id,
          customer_kind: "phone",
          case_id: case_id,
          session_external_id: session_id("call"),
          direction: "inbound"
        },
        "I booked, but I'm not sure if it's confirmed."
      )

    _ =
      ingest_message(
        %{
          channel_key: "sms",
          endpoint_address: endpoints.sms.address,
          from_address: "+15550009999",
          customer_external_id: customer_id,
          customer_kind: "phone",
          case_id: case_id,
          session_external_id: session_id("sms"),
          direction: "inbound"
        },
        "Running 15 mins late."
      )

    _ =
      Approvals.request_approval(tenant_id, %{
        case_id: case_id,
        session_id: payload.session_id,
        requested_by_type: "agent",
        request_payload: %{action: "schedule.override", details: "Squeeze into morning slot"}
      })

    case_id
  end

  defp use_case_b(tenant_id, endpoints) do
    customer_id = "cust-d2c-001"

    {:ok, payload} =
      ingest_message(
        %{
          channel_key: "instagram",
          endpoint_address: endpoints.instagram.address,
          from_address: "ig:shopper",
          customer_external_id: customer_id,
          case_category: "order_support",
          case_title: "Order #123 support",
          session_external_id: session_id("ig"),
          direction: "inbound"
        },
        "I want it delivered to Bangalore."
      )

    case_id = payload.case_id

    _ =
      ingest_message(
        %{
          channel_key: "whatsapp",
          endpoint_address: endpoints.whatsapp.address,
          from_address: "+15550008888",
          customer_external_id: customer_id,
          customer_kind: "phone",
          case_id: case_id,
          session_external_id: session_id("wa"),
          direction: "inbound"
        },
        "Where is my order?"
      )

    _ =
      ingest_message(
        %{
          channel_key: "email",
          endpoint_address: endpoints.email.address,
          from_address: "buyer@example.com",
          customer_external_id: customer_id,
          case_id: case_id,
          session_external_id: session_id("email"),
          subject: "Package arrived damaged",
          direction: "inbound"
        },
        "Package arrived damaged. Here are photos."
      )

    _ =
      Approvals.request_approval(tenant_id, %{
        case_id: case_id,
        session_id: payload.session_id,
        requested_by_type: "agent",
        request_payload: %{action: "refund", amount: 129.0, currency: "USD"}
      })

    case_id
  end

  defp use_case_c(tenant_id, endpoints) do
    customer_id = "cust-home-001"

    {:ok, payload} =
      ingest_message(
        %{
          channel_key: "webchat",
          endpoint_address: endpoints.webchat.address,
          from_address: "web:lead-42",
          customer_external_id: customer_id,
          case_category: "service_request",
          case_title: "AC repair request",
          session_external_id: session_id("web"),
          direction: "inbound"
        },
        "AC not working, can someone come today?"
      )

    case_id = payload.case_id

    _ =
      ingest_message(
        %{
          channel_key: "voice",
          endpoint_address: endpoints.voice.address,
          from_address: "+15550007777",
          customer_external_id: customer_id,
          customer_kind: "phone",
          case_id: case_id,
          session_external_id: session_id("call"),
          direction: "inbound"
        },
        "Did you get my message?"
      )

    _ =
      ingest_message(
        %{
          channel_key: "whatsapp",
          endpoint_address: endpoints.whatsapp.address,
          from_address: "+15550007777",
          customer_external_id: customer_id,
          customer_kind: "phone",
          case_id: case_id,
          session_external_id: session_id("wa"),
          direction: "inbound"
        },
        "Technician can arrive 3-5pm. Confirm?"
      )

    _ =
      ingest_message(
        %{
          channel_key: "sms",
          endpoint_address: endpoints.sms.address,
          from_address: "+15550007777",
          customer_external_id: customer_id,
          customer_kind: "phone",
          case_id: case_id,
          session_external_id: session_id("sms"),
          direction: "inbound"
        },
        "It broke again."
      )

    _ =
      Handoffs.request_handoff(tenant_id, %{
        case_id: case_id,
        session_id: payload.session_id,
        requested_by_type: "agent",
        target_channel_id: endpoints.slack.channel_id,
        target_endpoint_id: endpoints.slack.id,
        metadata: %{queue: "dispatch", reason: "Schedule technician"}
      })

    case_id
  end

  defp use_case_d(tenant_id, endpoints) do
    customer_id = "cust-saas-001"

    {:ok, payload} =
      ingest_message(
        %{
          channel_key: "email",
          endpoint_address: endpoints.email.address,
          from_address: "cto@startup.test",
          customer_external_id: customer_id,
          case_category: "incident",
          case_title: "API 500s incident",
          session_external_id: session_id("email"),
          subject: "API returning 500s",
          direction: "inbound"
        },
        "Your API is returning 500s."
      )

    case_id = payload.case_id

    _ =
      ingest_message(
        %{
          channel_key: "slack",
          endpoint_address: endpoints.slack.address,
          from_address: "slack:connect-thread",
          customer_external_id: customer_id,
          case_id: case_id,
          session_external_id: session_id("slack"),
          direction: "inbound"
        },
        "Any update? We are seeing outages."
      )

    _ =
      ingest_message(
        %{
          channel_key: "voice",
          endpoint_address: endpoints.voice.address,
          from_address: "+15550006666",
          customer_external_id: customer_id,
          customer_kind: "phone",
          case_id: case_id,
          session_external_id: session_id("call"),
          direction: "inbound"
        },
        "Can we jump on a quick call?"
      )

    _ =
      Handoffs.request_handoff(tenant_id, %{
        case_id: case_id,
        session_id: payload.session_id,
        requested_by_type: "agent",
        target_channel_id: endpoints.slack.channel_id,
        target_endpoint_id: endpoints.slack.id,
        metadata: %{queue: "engineering", reason: "Incident escalation"}
      })

    case_id
  end

  defp use_case_e(tenant_id, endpoints) do
    customer_id = "cust-food-001"

    {:ok, payload} =
      ingest_message(
        %{
          channel_key: "whatsapp",
          endpoint_address: endpoints.whatsapp.address,
          from_address: "+15550005555",
          customer_external_id: customer_id,
          customer_kind: "phone",
          case_category: "order_issue",
          case_title: "Order missing items",
          session_external_id: session_id("wa"),
          direction: "inbound"
        },
        "Order missing items."
      )

    case_id = payload.case_id

    _ =
      ingest_message(
        %{
          channel_key: "public",
          endpoint_address: endpoints.public.address,
          from_address: "ig:angry-review",
          customer_external_id: customer_id,
          customer_kind: "handle",
          case_id: case_id,
          session_external_id: session_id("public"),
          direction: "inbound"
        },
        "Terrible experience. Missing food."
      )

    _ =
      ingest_message(
        %{
          channel_key: "voice",
          endpoint_address: endpoints.voice.address,
          from_address: "+15550005555",
          customer_external_id: customer_id,
          customer_kind: "phone",
          case_id: case_id,
          session_external_id: session_id("call"),
          direction: "inbound"
        },
        "Please refund me."
      )

    _ =
      Approvals.request_approval(tenant_id, %{
        case_id: case_id,
        session_id: payload.session_id,
        requested_by_type: "agent",
        request_payload: %{action: "refund", amount: 45.0, currency: "USD"}
      })

    case_id
  end

  defp use_case_f(_tenant_id, endpoints) do
    customer_id = "cust-tuition-001"

    {:ok, payload} =
      ingest_message(
        %{
          channel_key: "whatsapp",
          endpoint_address: endpoints.whatsapp.address,
          from_address: "+15550004444",
          customer_external_id: customer_id,
          customer_kind: "phone",
          case_category: "lead",
          case_title: "Admissions lead",
          session_external_id: session_id("wa"),
          direction: "inbound"
        },
        "Fees? timings? demo class?"
      )

    case_id = payload.case_id

    _ =
      ingest_message(
        %{
          channel_key: "email",
          endpoint_address: endpoints.email.address,
          from_address: "parent@example.com",
          customer_external_id: customer_id,
          case_id: case_id,
          session_external_id: session_id("email"),
          subject: "Documents",
          direction: "inbound"
        },
        "Sharing student documents."
      )

    _ =
      ingest_message(
        %{
          channel_key: "telegram",
          endpoint_address: endpoints.telegram.address,
          from_address: "tg:student",
          customer_external_id: customer_id,
          case_id: case_id,
          session_external_id: session_id("telegram"),
          direction: "inbound"
        },
        "I missed class today."
      )

    _ =
      ingest_message(
        %{
          channel_key: "whatsapp",
          endpoint_address: endpoints.whatsapp.address,
          from_address: "+15550004444",
          customer_external_id: customer_id,
          customer_kind: "phone",
          case_id: case_id,
          session_external_id: session_id("wa-followup"),
          direction: "inbound"
        },
        "Payment overdue reminder."
      )

    case_id
  end

  defp ingest_message(params, text) do
    params = Map.new(params, fn {key, value} -> {to_string(key), value} end)

    event = %{
      "type" => "channel.message.received",
      "payload" => %{"text" => text}
    }

    Ingestion.ingest_events(Map.put(params, "event", event))
  end

  defp session_id(prefix) do
    prefix <> "-" <> Ecto.UUID.generate()
  end

  defp ensure_channels(tenant_id) do
    {:ok, voice} = Channels.ensure_voice_channel(tenant_id)
    {:ok, email} = Channels.ensure_email_channel(tenant_id)

    {:ok, whatsapp} = ensure_channel(tenant_id, "whatsapp", "WhatsApp", :whatsapp)
    {:ok, instagram} = ensure_channel(tenant_id, "instagram", "Instagram", :chat)
    {:ok, sms} = ensure_channel(tenant_id, "sms", "SMS", :custom)
    {:ok, webchat} = ensure_channel(tenant_id, "webchat", "Web Chat", :chat)
    {:ok, slack} = ensure_channel(tenant_id, "slack", "Slack", :custom)
    {:ok, telegram} = ensure_channel(tenant_id, "telegram", "Telegram", :chat)
    {:ok, public} = ensure_channel(tenant_id, "public", "Public", :custom)

    {:ok, voice_endpoint} = Channels.ensure_endpoint(tenant_id, voice.id, "+15555550101")
    {:ok, whatsapp_endpoint} = Channels.ensure_endpoint(tenant_id, whatsapp.id, "+15555550102")
    {:ok, instagram_endpoint} = Channels.ensure_endpoint(tenant_id, instagram.id, "ig:clinic")
    {:ok, sms_endpoint} = Channels.ensure_endpoint(tenant_id, sms.id, "+15555550103")
    {:ok, email_endpoint} = Channels.ensure_endpoint(tenant_id, email.id, "support@clinic.test")
    {:ok, webchat_endpoint} = Channels.ensure_endpoint(tenant_id, webchat.id, "web:home-services")
    {:ok, slack_endpoint} = Channels.ensure_endpoint(tenant_id, slack.id, "slack:internal")
    {:ok, telegram_endpoint} = Channels.ensure_endpoint(tenant_id, telegram.id, "tg:student")
    {:ok, public_endpoint} = Channels.ensure_endpoint(tenant_id, public.id, "public:instagram")

    %{
      voice: voice_endpoint,
      whatsapp: whatsapp_endpoint,
      instagram: instagram_endpoint,
      sms: sms_endpoint,
      email: email_endpoint,
      webchat: webchat_endpoint,
      slack: slack_endpoint,
      telegram: telegram_endpoint,
      public: public_endpoint
    }
  end

  defp ensure_channel(tenant_id, key, name, type) do
    Channels.ensure_channel(tenant_id, %{
      "name" => name,
      "key" => key,
      "type" => type,
      "status" => :active,
      "capabilities" => default_capabilities()
    })
  end

  defp default_capabilities do
    %{
      "supports" => %{
        "sync" => false,
        "attachments" => true,
        "multi_party" => true,
        "message_edits" => false,
        "typing" => true
      },
      "tools" => [
        "channel.message.send",
        "channel.thread.fetch",
        "channel.thread.close",
        "channel.handoff.request",
        "channel.handoff.transfer"
      ]
    }
  end
end
