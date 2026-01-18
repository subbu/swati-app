defmodule SwatiWeb.CallsLive.Show do
  use SwatiWeb, :live_view

  alias Swati.Calls

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.call_detail
        call={@call}
        primary_audio_url={@primary_audio_url}
        agent_name={@agent_name}
        status_badge={@status_badge}
        transcript_items={@transcript_items}
        waveform_context_json={@waveform_context_json}
        waveform_duration_ms={@waveform_duration_ms}
        current_scope={@current_scope}
        back_patch={~p"/calls"}
      />
    </Layouts.app>
    """
  end

  attr :call, :map, required: true
  attr :primary_audio_url, :string, default: nil
  attr :agent_name, :string, required: true
  attr :status_badge, :map, required: true
  attr :transcript_items, :list, required: true
  attr :waveform_context_json, :string, required: true
  attr :waveform_duration_ms, :integer, required: true
  attr :current_scope, :map, required: true
  attr :back_patch, :string, default: nil

  def call_detail(assigns) do
    ~H"""
    <div id="call-detail" class="space-y-10">
      <style>
        /* Refined animation system */
        @keyframes swati-fade-up {
          from { opacity: 0; transform: translateY(12px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @keyframes swati-fade-in {
          from { opacity: 0; }
          to { opacity: 1; }
        }
        @keyframes swati-scale-in {
          from { opacity: 0; transform: scale(0.96); }
          to { opacity: 1; transform: scale(1); }
        }
        @keyframes swati-pulse-subtle {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.7; }
        }

        #call-detail {
          animation: swati-fade-up 0.5s cubic-bezier(0.22, 1, 0.36, 1) forwards;
        }

        /* Active transcript highlight - refined */
        .swati-active-transcript {
          background: linear-gradient(135deg, rgba(59, 130, 246, 0.08) 0%, rgba(99, 102, 241, 0.06) 100%);
          box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.35), 0 4px 16px -4px rgba(59, 130, 246, 0.2);
          border-radius: 1.25rem;
          transition: all 0.3s cubic-bezier(0.22, 1, 0.36, 1);
        }

        /* Tooltip refinements */
        #call-waveform-tooltip {
          max-width: min(480px, 92vw);
          backdrop-filter: blur(12px);
          background: rgba(255, 255, 255, 0.95);
          box-shadow: 0 8px 32px -8px rgba(0, 0, 0, 0.12), 0 4px 16px -4px rgba(0, 0, 0, 0.08);
          animation: swati-scale-in 0.2s cubic-bezier(0.22, 1, 0.36, 1) forwards;
        }
        @media (prefers-color-scheme: dark) {
          #call-waveform-tooltip {
            background: rgba(30, 30, 35, 0.95);
          }
        }
        #call-waveform-tooltip .swati-tooltip-scroll {
          max-height: 240px;
          overflow: auto;
          scrollbar-width: thin;
        }

        /* Audio panel refinements */
        #call-audio-panel {
          transition: box-shadow 0.3s ease, transform 0.3s ease;
        }
        #call-audio-panel:hover {
          box-shadow: 0 8px 40px -12px rgba(0, 0, 0, 0.12), 0 4px 20px -8px rgba(0, 0, 0, 0.08);
        }

        /* Waveform container polish */
        #call-waveform-container {
          transition: box-shadow 0.25s ease;
          box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.06);
        }
        #call-waveform-container:hover {
          box-shadow: inset 0 1px 4px rgba(0, 0, 0, 0.08);
        }
        #call-waveform-container:focus-visible {
          outline: 2px solid rgba(59, 130, 246, 0.5);
          outline-offset: 2px;
        }

        /* Play button pulse when playing */
        #call-audio-play.is-playing {
          animation: swati-pulse-subtle 2s ease-in-out infinite;
        }

        /* Transcript items - staggered entrance */
        #transcript-list > div {
          animation: swati-fade-up 0.4s cubic-bezier(0.22, 1, 0.36, 1) backwards;
        }
        #transcript-list > div:nth-child(1) { animation-delay: 0.1s; }
        #transcript-list > div:nth-child(2) { animation-delay: 0.15s; }
        #transcript-list > div:nth-child(3) { animation-delay: 0.2s; }
        #transcript-list > div:nth-child(4) { animation-delay: 0.25s; }
        #transcript-list > div:nth-child(5) { animation-delay: 0.3s; }
        #transcript-list > div:nth-child(n+6) { animation-delay: 0.35s; }

        /* Message bubble hover states */
        [data-transcript-item="message"] {
          transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        [data-transcript-item="message"]:hover {
          transform: translateY(-1px);
          box-shadow: 0 4px 16px -4px rgba(0, 0, 0, 0.1);
        }

        /* Tool card refinements */
        [data-transcript-item="tool"] {
          transition: transform 0.2s ease, box-shadow 0.25s ease, border-color 0.2s ease;
        }
        [data-transcript-item="tool"]:hover {
          transform: translateY(-2px);
          box-shadow: 0 8px 24px -8px rgba(0, 0, 0, 0.1);
          border-color: rgba(99, 102, 241, 0.3);
        }

        /* Button micro-interactions */
        #call-audio-panel button {
          transition: transform 0.15s ease, background-color 0.2s ease, box-shadow 0.2s ease;
        }
        #call-audio-panel button:active {
          transform: scale(0.95);
        }

        /* Rate button style */
        #call-audio-rate {
          font-variant-numeric: tabular-nums;
          transition: all 0.2s ease;
        }
        #call-audio-rate:hover {
          background: rgba(0, 0, 0, 0.05);
        }

        /* Speaker legend dots - refined */
        .swati-speaker-dot {
          transition: transform 0.2s ease;
        }
        .swati-speaker-dot:hover {
          transform: scaleX(1.3);
        }

        /* Accordion refinements */
        .swati-tool-accordion summary {
          cursor: pointer;
          transition: background-color 0.2s ease;
        }
        .swati-tool-accordion summary:hover {
          background-color: rgba(0, 0, 0, 0.02);
        }
        .swati-tool-accordion[open] summary .swati-accordion-chevron {
          transform: rotate(180deg);
        }
        .swati-accordion-chevron {
          transition: transform 0.25s cubic-bezier(0.22, 1, 0.36, 1);
        }

        /* Pre block styling */
        .swati-code-block {
          font-family: 'JetBrains Mono', 'Fira Code', 'SF Mono', monospace;
          font-size: 11px;
          line-height: 1.6;
          letter-spacing: -0.01em;
        }

        /* Transcript click hint */
        [data-transcript-item] {
          cursor: pointer;
          position: relative;
        }
        [data-transcript-item]::after {
          content: 'Click to seek';
          position: absolute;
          bottom: 100%;
          left: 50%;
          transform: translateX(-50%) translateY(4px);
          background: rgba(15, 23, 42, 0.9);
          color: white;
          padding: 4px 10px;
          border-radius: 6px;
          font-size: 11px;
          font-weight: 500;
          white-space: nowrap;
          opacity: 0;
          visibility: hidden;
          pointer-events: none;
          transition: opacity 0.15s ease, visibility 0.15s ease, transform 0.15s ease;
          z-index: 30;
        }
        [data-transcript-item]:hover::after {
          opacity: 1;
          visibility: visible;
          transform: translateX(-50%) translateY(-4px);
        }

        /* Dark mode tooltip */
        @media (prefers-color-scheme: dark) {
          [data-transcript-item]::after {
            background: rgba(255, 255, 255, 0.95);
            color: rgba(15, 23, 42, 0.9);
          }
        }
      </style>

      <header class="flex flex-wrap items-start justify-between gap-6">
        <div class="space-y-3 min-w-0 flex-1">
          <div class="flex flex-wrap items-center gap-3">
            <h1 class="text-2xl md:text-[1.75rem] font-semibold text-foreground tracking-[-0.02em] leading-tight">
              Conversation with {@agent_name}
            </h1>
            <.badge size="sm" variant="soft" color={@status_badge.color}>
              {@status_badge.label}
            </.badge>
          </div>
          <div class="flex flex-wrap items-center gap-2.5 text-[13px] text-foreground-soft">
            <div class="flex items-center gap-1.5">
              <.icon name="hero-phone" class="size-3.5 text-foreground-softer" />
              <span class="font-medium">{@call.from_number}</span>
              <.icon name="hero-arrow-right" class="size-3 text-foreground-softer" />
              <span class="font-medium">{@call.to_number}</span>
            </div>
            <span class="text-foreground-softer/60">•</span>
            <span>{format_long_datetime(@call.started_at, @current_scope.tenant)}</span>
            <span class="text-foreground-softer/60">•</span>
            <span class="font-medium">{format_duration(@call.duration_seconds)}</span>
          </div>
        </div>
        <div class="flex items-center gap-2 shrink-0">
          <.button :if={@back_patch} patch={@back_patch} variant="ghost" size="sm" class="gap-1.5">
            <.icon name="hero-arrow-left" class="size-4" />
            <span>Back</span>
          </.button>
        </div>
      </header>

      <div class="space-y-8">
        <div class="space-y-8">
          <section
            id="call-audio-panel"
            phx-hook=".CallAudioPlayer"
            data-audio-url={@primary_audio_url || ""}
            data-duration={@call.duration_seconds || 0}
            data-duration-ms={@waveform_duration_ms || 0}
            data-agent-label={@agent_name}
            data-waveform-context={@waveform_context_json}
            data-seed={@call.id}
            class="rounded-[1.75rem] border border-base-300/80 bg-base-100/95 p-6 md:sticky md:top-6 md:z-30 md:p-8 shadow-[0_1px_3px_rgba(0,0,0,0.04),0_4px_12px_-2px_rgba(0,0,0,0.06)] space-y-5"
          >
            <%= if @primary_audio_url do %>
              <div class="flex items-center justify-between gap-4 text-[11px] text-foreground-softer pt-1">
                <div class="flex items-center gap-5">
                  <div class="flex items-center gap-2 group cursor-default">
                    <span class="swati-speaker-dot inline-block h-1.5 w-5 rounded-full bg-[#2563eb]">
                    </span>
                    <span class="uppercase tracking-wider font-semibold text-[#2563eb]">
                      {@agent_name}
                    </span>
                  </div>
                  <div class="flex items-center gap-2 group cursor-default">
                    <span class="swati-speaker-dot inline-block h-1.5 w-5 rounded-full bg-[#a855f7]">
                    </span>
                    <span class="uppercase tracking-wider font-semibold text-[#a855f7]">
                      Customer
                    </span>
                  </div>
                </div>
                <span class="hidden md:flex items-center gap-1.5 text-foreground-softer/70">
                  <.icon name="hero-cursor-arrow-ripple" class="size-3.5" />
                  <span>Click & drag to analyze</span>
                </span>
              </div>

              <div id="call-waveform-wrap" class="relative pt-1">
                <div
                  id="call-waveform-container"
                  class="call-waveform h-32 rounded-2xl bg-gradient-to-b from-base-200/50 to-base-200/70 overflow-hidden cursor-pointer"
                  phx-update="ignore"
                  role="slider"
                  tabindex="0"
                  aria-label="Audio seek bar"
                  aria-valuemin="0"
                  aria-valuemax={@call.duration_seconds || 0}
                  aria-valuenow="0"
                  style="--waveform-color: rgba(148,163,184,0.65); --waveform-color-played: rgba(37,99,235,0.92); --waveform-agent-bg: rgba(37,99,235,0.07); --waveform-customer-bg: rgba(168,85,247,0.07); --waveform-selection-bg: rgba(37,99,235,0.14); --waveform-selection-border: rgba(37,99,235,0.5); --waveform-hover-line: rgba(15,23,42,0.12);"
                >
                  <canvas id="call-waveform" class="call-waveform-canvas"></canvas>
                </div>

                <div
                  id="call-waveform-tooltip"
                  class="hidden absolute z-20 rounded-2xl border border-base-300/60 bg-base-100/98 px-4 py-3.5 text-foreground text-xs pointer-events-auto"
                >
                </div>
              </div>

              <div class="flex flex-wrap items-center gap-3 pt-1">
                <.button
                  id="call-audio-play"
                  size="icon"
                  variant="solid"
                  color="primary"
                  class="size-11 rounded-xl shadow-md shadow-primary/20 hover:shadow-lg hover:shadow-primary/25 transition-shadow"
                >
                  <.icon name="hero-play-solid" class="size-5 js-play-icon" />
                  <.icon name="hero-pause-solid" class="size-5 js-pause-icon hidden" />
                </.button>

                <div class="flex items-center gap-1 bg-base-200/50 rounded-xl p-1">
                  <.button
                    id="call-audio-rewind"
                    size="icon-sm"
                    variant="ghost"
                    class="rounded-lg hover:bg-base-200"
                  >
                    <.icon name="hero-backward" class="size-4" />
                  </.button>
                  <.button
                    id="call-audio-forward"
                    size="icon-sm"
                    variant="ghost"
                    class="rounded-lg hover:bg-base-200"
                  >
                    <.icon name="hero-forward" class="size-4" />
                  </.button>
                </div>

                <button
                  id="call-audio-rate"
                  type="button"
                  class="text-[13px] font-medium text-foreground-soft rounded-lg px-2.5 py-1.5 hover:bg-base-200/80 active:bg-base-200 tabular-nums min-w-[52px] text-center"
                >
                  1.0x
                </button>

                <div class="ml-auto flex items-center gap-1.5 text-[13px] text-foreground-soft tabular-nums">
                  <span id="call-audio-current-time" class="font-medium text-foreground">0:00</span>
                  <span class="text-foreground-softer/60">/</span>
                  <span id="call-audio-total-time">{format_duration(@call.duration_seconds)}</span>
                </div>
              </div>

              <audio id="call-audio" preload="metadata" src={@primary_audio_url} class="hidden">
              </audio>
            <% else %>
              <div class="flex items-center gap-3 py-6 text-sm text-foreground-soft">
                <.icon name="hero-speaker-x-mark" class="size-5 text-foreground-softer" />
                <span>No audio recording available for this call.</span>
              </div>
            <% end %>

            <script :type={Phoenix.LiveView.ColocatedHook} name=".CallAudioPlayer">
              const RATES = [1.0, 1.25, 1.5, 2.0];
              const SEEK_STEP_SECONDS = 10;
              const DRAG_SELECT_THRESHOLD_PX = 6;
              const MIN_SELECTION_SECONDS = 0.20;

              const NEAREST_UTTERANCE_MAX_DISTANCE_MS = 2000;
              const NEAREST_TOOL_MAX_DISTANCE_MS = 1200;

              function clamp(n, min, max) {
                return Math.min(Math.max(n, min), max);
              }

              function safeJsonParse(str, fallback) {
                try {
                  if (!str || String(str).trim() === "") return fallback;
                  return JSON.parse(str);
                } catch (_e) {
                  return fallback;
                }
              }

              function escapeHtml(s) {
                const str = (s ?? "").toString();
                return str
                  .replaceAll("&", "&amp;")
                  .replaceAll("<", "&lt;")
                  .replaceAll(">", "&gt;")
                  .replaceAll("\"", "&quot;")
                  .replaceAll("'", "&#039;");
              }

              function truncateText(s, maxLen = 220) {
                const str = (s ?? "").toString().trim();
                if (str.length <= maxLen) return str;
                return str.slice(0, Math.max(0, maxLen - 1)) + "…";
              }

              function formatTime(totalSeconds) {
                if (!Number.isFinite(totalSeconds) || totalSeconds < 0) return "0:00";
                const seconds = Math.floor(totalSeconds);
                const minutes = Math.floor(seconds / 60);
                const remaining = seconds % 60;
                return `${minutes}:${String(remaining).padStart(2, "0")}`;
              }

              function formatRate(rate) {
                if (rate === 1 || rate === 1.5 || rate === 2) return `${rate.toFixed(1)}x`;
                return `${rate.toFixed(2)}x`;
              }

              function normalizeSpeaker(value) {
                const v = (value ?? "").toString().toLowerCase();
                if (v === "agent" || v === "assistant" || v === "bot") return "agent";
                if (v === "caller" || v === "customer" || v === "user") return "customer";
                if (v === "tool") return "tool";
                return v || "agent";
              }

              function hashStringToUint32(str) {
                let h = 2166136261;
                for (let i = 0; i < str.length; i++) {
                  h ^= str.charCodeAt(i);
                  h = Math.imul(h, 16777619);
                }
                return h >>> 0;
              }

              function mulberry32(seed) {
                return function () {
                  let t = (seed += 0x6D2B79F5);
                  t = Math.imul(t ^ (t >>> 15), t | 1);
                  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
                  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
                };
              }

              function buildPlaceholderPeaks(count, seedStr) {
                const rand = mulberry32(hashStringToUint32(seedStr || "waveform"));
                const peaks = new Array(count);
                let prev = rand();

                for (let i = 0; i < count; i++) {
                  const next = rand();
                  const smooth = prev * 0.58 + next * 0.42;
                  prev = smooth;

                  // Higher contrast to feel more "oscillatory"
                  let amp = Math.pow(smooth, 2.15) * 0.92 + 0.08;
                  if (rand() < 0.10) amp *= 0.22; // occasional quieter gaps
                  peaks[i] = clamp(amp, 0.02, 1.0);
                }

                return peaks;
              }

              function resamplePeaksMax(peaks, targetCount) {
                if (!Array.isArray(peaks) || peaks.length === 0) return new Array(targetCount).fill(0.12);
                if (peaks.length === targetCount) return peaks;

                const out = new Array(targetCount);
                const bucket = peaks.length / targetCount;

                for (let i = 0; i < targetCount; i++) {
                  const start = Math.floor(i * bucket);
                  const end = Math.max(start + 1, Math.floor((i + 1) * bucket));
                  let max = 0;

                  for (let j = start; j < end && j < peaks.length; j++) {
                    max = Math.max(max, peaks[j] || 0);
                  }
                  out[i] = max;
                }

                return out;
              }

              function guessMimeType(url, headerType) {
                if (headerType && headerType.includes("/")) return headerType;

                const clean = (url || "").split("?")[0].toLowerCase();
                if (clean.endsWith(".mp3")) return "audio/mpeg";
                if (clean.endsWith(".wav")) return "audio/wav";
                if (clean.endsWith(".m4a")) return "audio/mp4";
                if (clean.endsWith(".ogg") || clean.endsWith(".opus")) return "audio/ogg";
                return "application/octet-stream";
              }

              function cssVar(el, name, fallback) {
                const v = getComputedStyle(el).getPropertyValue(name);
                return v && v.trim() !== "" ? v.trim() : fallback;
              }

              function computePeaksFromAudioBuffer(audioBuffer, targetCount) {
                const channels = Math.max(1, audioBuffer.numberOfChannels || 1);
                const samples = audioBuffer.length || 0;
                if (samples === 0) return null;

                const blockSize = Math.max(1, Math.floor(samples / targetCount));
                const peaks = new Array(targetCount).fill(0);

                for (let i = 0; i < targetCount; i++) {
                  const start = i * blockSize;
                  const end = i === targetCount - 1 ? samples : Math.min(samples, start + blockSize);
                  let max = 0;

                  for (let ch = 0; ch < channels; ch++) {
                    const data = audioBuffer.getChannelData(ch);
                    for (let j = start; j < end; j++) {
                      const v = Math.abs(data[j]);
                      if (v > max) max = v;
                    }
                  }

                  peaks[i] = max;
                }

                const maxPeak = peaks.reduce((m, v) => Math.max(m, v), 0) || 1;
                return peaks.map((v) => v / maxPeak);
              }

              function waitForEvent(target, eventName, timeoutMs = 2000) {
                return new Promise((resolve) => {
                  let done = false;

                  const cleanup = (result) => {
                    if (done) return;
                    done = true;
                    clearTimeout(timer);
                    target.removeEventListener(eventName, onEvent);
                    resolve(result);
                  };

                  const onEvent = () => cleanup(true);
                  const timer = setTimeout(() => cleanup(false), timeoutMs);

                  target.addEventListener(eventName, onEvent, { once: true });
                });
              }

              export default {
                mounted() {
                  this.audioEl = this.el.querySelector("#call-audio");
                  this.waveformEl = this.el.querySelector("#call-waveform-container");
                  this.canvasEl = this.el.querySelector("#call-waveform");
                  this.tooltipEl = this.el.querySelector("#call-waveform-tooltip");

                  this.playBtn = this.el.querySelector("#call-audio-play");
                  this.rateBtn = this.el.querySelector("#call-audio-rate");
                  this.rewindBtn = this.el.querySelector("#call-audio-rewind");
                  this.forwardBtn = this.el.querySelector("#call-audio-forward");

                  this.currentTimeEl = this.el.querySelector("#call-audio-current-time");
                  this.totalTimeEl = this.el.querySelector("#call-audio-total-time");

                  if (!this.audioEl || !this.waveformEl || !this.canvasEl) return;

                  this.audioUrl = (this.el.dataset.audioUrl || "").trim() || this.audioEl.getAttribute("src") || "";
                  this.datasetDuration = Number(this.el.dataset.duration || 0) || 0;
                  this.datasetDurationMs = Number(this.el.dataset.durationMs || 0) || 0;
                  this.seed = (this.el.dataset.seed || "").toString() || this.audioUrl || "call-waveform";

                  // Timeline/speaker context for tooltips + speaker overlays
                  const context = safeJsonParse(this.el.dataset.waveformContext, {});
                  this.agentLabel = (context.agent_label || this.el.dataset.agentLabel || "Agent").toString();
                  this.customerLabel = (context.customer_label || "Customer").toString();
                  this.timelineDurationMs = Number(context.duration_ms || 0) || 0;

                  this.speakerSegments = Array.isArray(context.speaker_segments) ? context.speaker_segments.slice() : [];
                  this.utterances = Array.isArray(context.utterances) ? context.utterances.slice() : [];
                  this.toolCalls = Array.isArray(context.tool_calls) ? context.tool_calls.slice() : [];
                  this.markers = Array.isArray(context.markers) ? context.markers.slice() : [];

                  this.speakerSegments.sort((a, b) => Number(a?.start_ms || 0) - Number(b?.start_ms || 0));
                  this.utterances.sort((a, b) => Number(a?.start_ms || 0) - Number(b?.start_ms || 0));
                  this.toolCalls.sort((a, b) => Number(a?.start_ms || 0) - Number(b?.start_ms || 0));

                  this.maxContextMs = 0;
                  const bumpMax = (n) => { if (Number.isFinite(n) && n > this.maxContextMs) this.maxContextMs = n; };
                  for (const s of this.speakerSegments) bumpMax(Number(s?.end_ms || 0));
                  for (const u of this.utterances) bumpMax(Number(u?.end_ms || 0));
                  for (const t of this.toolCalls) bumpMax(Number(t?.end_ms || 0));

                  this.ctx = this.canvasEl.getContext("2d");
                  this.baseColor = cssVar(this.waveformEl, "--waveform-color", "rgba(148,163,184,0.72)");
                  this.playedColor = cssVar(this.waveformEl, "--waveform-color-played", "rgba(37,99,235,0.95)");
                  this.agentBg = cssVar(this.waveformEl, "--waveform-agent-bg", "rgba(37,99,235,0.08)");
                  this.customerBg = cssVar(this.waveformEl, "--waveform-customer-bg", "rgba(168,85,247,0.08)");
                  this.selectionBg = cssVar(this.waveformEl, "--waveform-selection-bg", "rgba(37,99,235,0.16)");
                  this.selectionBorder = cssVar(this.waveformEl, "--waveform-selection-border", "rgba(37,99,235,0.55)");
                  this.hoverLineColor = cssVar(this.waveformEl, "--waveform-hover-line", "rgba(0,0,0,0.12)");

                  // Start with a placeholder waveform (fast + no CORS needed)
                  this.rawPeaks = buildPlaceholderPeaks(1050, this.seed);

                  // Playback rate
                  this.rateIndex = 0;
                  this.audioEl.playbackRate = RATES[this.rateIndex];
                  if (this.rateBtn) this.rateBtn.textContent = formatRate(RATES[this.rateIndex]);

                  // Transcript elements for playback highlighting + click-to-seek
                  this.transcriptRoot = null;
                  this.transcriptEls = [];
                  this.transcriptMeta = [];
                  this.activeTranscriptEl = null;

                  this.onTranscriptClick = (e) => {
                    // Ignore clicks on interactive elements so tool accordions/buttons work normally
                    const interactive = e.target.closest("button, a, summary, input, textarea, select");
                    if (interactive) return;

                    const item = e.target.closest("[data-transcript-item]");
                    if (!item) return;
                    const startMs = Number(item.dataset.startMs || 0);
                    this.seekTo(startMs / 1000);
                  };

                  this.buildTranscriptIndex = () => {
                    this.transcriptMeta = (this.transcriptEls || [])
                      .map((el, idx) => {
                        const start = Number(el.dataset.startMs || 0);
                        const rawEnd = Number(el.dataset.endMs || start);
                        const end = Math.max(rawEnd, start);
                        const type = (el.dataset.transcriptItem || "message").toString();
                        const dur = Math.max(0, end - start);
                        return { el, idx, type, start, end, dur };
                      })
                      .sort((a, b) => (a.start - b.start) || (a.dur - b.dur) || (a.idx - b.idx));
                  };

                  this.refreshTranscriptIndex = () => {
                    const root = document.getElementById("transcript-list");

                    if (root !== this.transcriptRoot) {
                      if (this.transcriptRoot) this.transcriptRoot.removeEventListener("click", this.onTranscriptClick);
                      this.transcriptRoot = root;
                      if (this.transcriptRoot) this.transcriptRoot.addEventListener("click", this.onTranscriptClick);
                    }

                    this.transcriptEls = Array.from(this.transcriptRoot?.querySelectorAll("[data-transcript-item]") || []);
                    this.buildTranscriptIndex();
                  };

                  this.refreshTranscriptIndex();

                  // Hover/selection state
                  this.hoverRatio = null;
                  this.isHovering = false;
                  this.isSelecting = false;
                  this.didDrag = false;
                  this.pointerDownX = 0;
                  this.selection = null; // { startRatio, endRatio, startMs, endMs }

                  // Smooth progress animation while playing
                  this.animFrame = null;
                  this.isAnimating = false;
                  this.startAnimationLoop = () => {
                    if (this.isAnimating) return;
                    this.isAnimating = true;

                    const tick = () => {
                      if (!this.isAnimating) return;
                      this.draw();
                      this.animFrame = requestAnimationFrame(tick);
                    };

                    this.animFrame = requestAnimationFrame(tick);
                  };

                  this.stopAnimationLoop = () => {
                    this.isAnimating = false;
                    if (this.animFrame) {
                      cancelAnimationFrame(this.animFrame);
                      this.animFrame = null;
                    }
                  };

                  // Resize handling
                  this.resizeObserver = new ResizeObserver(() => this.draw());
                  this.resizeObserver.observe(this.waveformEl);

                  // Audio event handlers
                  this.onLoadedMetadata = () => {
                    this.updateDurationUI();
                    this.updateTimeUI();
                    this.updateActiveTranscript();
                    this.draw();
                  };

                  this.onTimeUpdate = () => {
                    this.updateTimeUI();
                    this.updateActiveTranscript();
                    this.draw();
                  };

                  this.onPlayPause = () => {
                    const isPlaying = this.updatePlayUI();
                    this.updateActiveTranscript();
                    if (isPlaying) this.startAnimationLoop();
                    else this.stopAnimationLoop();
                    this.draw();
                  };

                  this.audioEl.addEventListener("loadedmetadata", this.onLoadedMetadata);
                  this.audioEl.addEventListener("timeupdate", this.onTimeUpdate);
                  this.audioEl.addEventListener("play", this.onPlayPause);
                  this.audioEl.addEventListener("pause", this.onPlayPause);
                  this.audioEl.addEventListener("ended", this.onPlayPause);

                  // Control handlers
                  this.onPlayClick = async () => {
                    try {
                      if (this.audioEl.paused || this.audioEl.ended) {
                        await this.audioEl.play();
                      } else {
                        this.audioEl.pause();
                      }
                    } catch (_e) {}
                  };

                  this.onRateClick = () => {
                    this.rateIndex = (this.rateIndex + 1) % RATES.length;
                    const rate = RATES[this.rateIndex];
                    this.audioEl.playbackRate = rate;
                    if (this.rateBtn) this.rateBtn.textContent = formatRate(rate);
                  };

                  this.onRewindClick = () => this.seekBy(-SEEK_STEP_SECONDS);
                  this.onForwardClick = () => this.seekBy(SEEK_STEP_SECONDS);

                  if (this.playBtn) this.playBtn.addEventListener("click", this.onPlayClick);
                  if (this.rateBtn) this.rateBtn.addEventListener("click", this.onRateClick);
                  if (this.rewindBtn) this.rewindBtn.addEventListener("click", this.onRewindClick);
                  if (this.forwardBtn) this.forwardBtn.addEventListener("click", this.onForwardClick);

                  // Pointer interactions: hover tooltip + drag selection (click = seek)
                  this.ratioFromClientX = (clientX) => {
                    const rect = this.waveformEl.getBoundingClientRect();
                    if (rect.width <= 0) return 0;
                    return clamp((clientX - rect.left) / rect.width, 0, 1);
                  };

                  this.durationMs = () => {
                    const d = this.audioEl?.duration;
                    if (Number.isFinite(d) && d > 0) return d * 1000;

                    if (this.datasetDuration > 0) return this.datasetDuration * 1000;
                    if (this.datasetDurationMs > 0) return this.datasetDurationMs;
                    if (this.timelineDurationMs > 0) return this.timelineDurationMs;
                    if (this.maxContextMs > 0) return this.maxContextMs;

                    return 0;
                  };

                  this.speakerForMs = (ms) => {
                    const t = Number(ms || 0);
                    for (const seg of this.speakerSegments) {
                      const s = Number(seg?.start_ms ?? -1);
                      const e = Number(seg?.end_ms ?? -1);
                      if (s >= 0 && e >= 0 && t >= s && t <= e) return normalizeSpeaker(seg?.speaker);
                    }
                    // fallback: infer from utterance
                    for (const u of this.utterances) {
                      const s = Number(u?.start_ms ?? -1);
                      const e = Number(u?.end_ms ?? -1);
                      if (s >= 0 && e >= 0 && t >= s && t <= e) return normalizeSpeaker(u?.speaker);
                    }
                    return "agent";
                  };

                  this.labelForSpeaker = (speaker) => {
                    const sp = normalizeSpeaker(speaker);
                    if (sp === "customer") return this.customerLabel;
                    if (sp === "agent") return this.agentLabel;
                    return sp;
                  };

                  this.findUtterancesInRange = (startMs, endMs, limit = 8) => {
                    const a = Number(startMs || 0);
                    const b = Number(endMs || 0);
                    const lo = Math.min(a, b);
                    const hi = Math.max(a, b);

                    const out = [];
                    for (const u of this.utterances) {
                      const s = Number(u?.start_ms ?? -1);
                      const e = Number(u?.end_ms ?? -1);
                      if (s < 0 || e < 0) continue;
                      const overlaps = s <= hi && e >= lo;
                      if (!overlaps) continue;

                      out.push(u);
                      if (out.length >= limit) break;
                    }
                    return out;
                  };

                  this.findToolCallsInRange = (startMs, endMs, limit = 6) => {
                    const a = Number(startMs || 0);
                    const b = Number(endMs || 0);
                    const lo = Math.min(a, b);
                    const hi = Math.max(a, b);

                    const out = [];
                    for (const t of this.toolCalls) {
                      const s = Number(t?.start_ms ?? -1);
                      const e = Number(t?.end_ms ?? -1);
                      if (s < 0 || e < 0) continue;
                      const overlaps = s <= hi && e >= lo;
                      if (!overlaps) continue;

                      out.push(t);
                      if (out.length >= limit) break;
                    }
                    return out;
                  };

                  this.findNearestUtteranceAt = (ms, maxDistanceMs = NEAREST_UTTERANCE_MAX_DISTANCE_MS) => {
                    const t = Number(ms || 0);
                    let best = null;
                    let bestDist = Number.POSITIVE_INFINITY;

                    for (const u of this.utterances) {
                      const s = Number(u?.start_ms ?? -1);
                      const e = Number(u?.end_ms ?? s);
                      if (s < 0) continue;

                      const dist = t < s ? (s - t) : (t > e ? (t - e) : 0);
                      if (dist < bestDist) {
                        bestDist = dist;
                        best = u;
                        if (dist === 0) break;
                      }
                    }

                    if (!best || bestDist > maxDistanceMs) return null;
                    return best;
                  };

                  this.findNearestToolCallsAt = (ms, maxDistanceMs = NEAREST_TOOL_MAX_DISTANCE_MS, limit = 6) => {
                    const t = Number(ms || 0);
                    const scored = [];

                    for (const tc of this.toolCalls) {
                      const s = Number(tc?.start_ms ?? -1);
                      const e = Number(tc?.end_ms ?? s);
                      if (s < 0) continue;

                      const dist = t < s ? (s - t) : (t > e ? (t - e) : 0);
                      if (dist <= maxDistanceMs) scored.push({ tc, dist });
                    }

                    scored.sort((a, b) => a.dist - b.dist);
                    return scored.slice(0, limit).map((x) => x.tc);
                  };

                  this.updateTooltip = ({ mode, clientX, startMs, endMs }) => {
                    if (!this.tooltipEl) return;

                    const rect = this.waveformEl.getBoundingClientRect();
                    const x = clamp(clientX - rect.left, 14, rect.width - 14);

                    const durationMs = this.durationMs();
                    const a = clamp(Number(startMs || 0), 0, durationMs || Number.MAX_SAFE_INTEGER);
                    const b = clamp(Number(endMs ?? a), 0, durationMs || Number.MAX_SAFE_INTEGER);

                    const lo = Math.min(a, b);
                    const hi = Math.max(a, b);

                    // Hover tooltips should not steal pointer events (keeps hover + hover-line stable)
                    this.tooltipEl.style.pointerEvents = mode === "selection" ? "auto" : "none";

                    const headerTime =
                      mode === "selection"
                        ? `${formatTime(lo / 1000)} – ${formatTime(hi / 1000)}`
                        : formatTime(lo / 1000);

                    const speaker = this.speakerForMs(lo);
                    const speakerLabel = this.labelForSpeaker(speaker);

                    const utterances =
                      mode === "selection"
                        ? this.findUtterancesInRange(lo, hi, 10)
                        : (() => {
                            const hits = this.findUtterancesInRange(lo, lo, 1);
                            if (hits.length > 0) return hits;
                            const nearest = this.findNearestUtteranceAt(lo);
                            return nearest ? [nearest] : [];
                          })();

                    const tools =
                      mode === "selection"
                        ? this.findToolCallsInRange(lo, hi, 10)
                        : (() => {
                            const hits = this.findToolCallsInRange(lo, lo, 6);
                            if (hits.length > 0) return hits;
                            return this.findNearestToolCallsAt(lo);
                          })();

                    const utterHtml =
                      utterances.length === 0
                        ? `<div class="text-foreground-soft">No transcript around this point.</div>`
                        : (mode === "selection"
                            ? `<div class="swati-tooltip-scroll space-y-2">` +
                              utterances
                                .map((u) => {
                                  const sp = this.labelForSpeaker(u?.speaker);
                                  return `<div class="space-y-1">
                                      <div class="text-[11px] uppercase tracking-wide text-foreground-softer">${escapeHtml(sp)}</div>
                                      <div class="text-sm leading-relaxed">${escapeHtml(truncateText(u?.text, 260))}</div>
                                    </div>`;
                                })
                                .join("") +
                              `</div>`
                            : `<div class="text-sm leading-relaxed">${escapeHtml(truncateText(utterances[0]?.text, 260))}</div>`);

                    const toolHtml =
                      tools.length === 0
                        ? ""
                        : `<div class="mt-3 space-y-2">
                            <div class="text-[11px] uppercase tracking-wide text-foreground-softer">Tool calls</div>
                            <div class="space-y-2">
                              ${tools
                                .map((t) => {
                                  const name = escapeHtml((t?.name ?? "tool").toString());
                                  const status = escapeHtml((t?.status ?? "succeeded").toString());
                                  const summary = truncateText((t?.response_summary ?? "").toString(), 120);
                                  return `<div class="space-y-1">
                                            <div class="flex items-center justify-between gap-3">
                                              <div class="text-xs text-foreground">${name}</div>
                                              <div class="text-[11px] text-foreground-softer uppercase tracking-wide">${status}</div>
                                            </div>
                                            ${summary ? `<div class="text-[11px] text-foreground-soft leading-snug">${escapeHtml(summary)}</div>` : ""}
                                          </div>`;
                                })
                                .join("")}
                            </div>
                          </div>`;

                    const title =
                      mode === "selection"
                        ? `<div class="text-[11px] uppercase tracking-wide text-foreground-softer">Selected segment</div>`
                        : `<div class="text-[11px] uppercase tracking-wide text-foreground-softer">Hover</div>`;

                    this.tooltipEl.innerHTML = `
                      <div class="space-y-2">
                        ${title}
                        <div class="flex items-center justify-between gap-3">
                          <div class="text-xs font-semibold text-foreground">${escapeHtml(speakerLabel)}</div>
                          <div class="text-xs font-mono text-foreground-softer">${escapeHtml(headerTime)}</div>
                        </div>
                        ${utterHtml}
                        ${toolHtml}
                      </div>
                    `;

                    this.tooltipEl.style.left = `${x}px`;
                    this.tooltipEl.style.top = `-6px`;
                    this.tooltipEl.style.transform = `translate(-50%, -100%)`;
                    this.tooltipEl.classList.remove("hidden");
                  };

                  this.hideTooltip = () => {
                    if (!this.tooltipEl) return;
                    if (this.selection) return; // keep visible for selection
                    this.tooltipEl.classList.add("hidden");
                  };

                  this.onPointerEnter = () => {
                    this.isHovering = true;
                  };

                  this.onPointerLeave = () => {
                    this.isHovering = false;
                    this.hoverRatio = null;
                    this.hideTooltip();
                    this.draw();
                  };

                  this.onPointerDown = (e) => {
                    if (e.button != null && e.button !== 0) return;
                    this.isSelecting = true;
                    this.didDrag = false;
                    this.pointerDownX = e.clientX;

                    const r = this.ratioFromClientX(e.clientX);
                    this.hoverRatio = r;

                    this.selection = {
                      startRatio: r,
                      endRatio: r,
                      startMs: (this.durationMs() || 0) * r,
                      endMs: (this.durationMs() || 0) * r
                    };

                    this.waveformEl.setPointerCapture?.(e.pointerId);
                    this.updateTooltip({ mode: "selection", clientX: e.clientX, startMs: this.selection.startMs, endMs: this.selection.endMs });
                    this.draw();
                  };

                  this.onPointerMove = (e) => {
                    const r = this.ratioFromClientX(e.clientX);
                    this.hoverRatio = r;

                    const durationMs = this.durationMs() || 0;
                    const ms = durationMs * r;

                    if (this.isSelecting && this.selection) {
                      if (Math.abs(e.clientX - this.pointerDownX) > DRAG_SELECT_THRESHOLD_PX) this.didDrag = true;

                      this.selection.endRatio = r;
                      this.selection.endMs = ms;

                      this.updateTooltip({ mode: "selection", clientX: e.clientX, startMs: this.selection.startMs, endMs: this.selection.endMs });
                      this.draw();
                      return;
                    }

                    // Hover tooltip (only when no selection is pinned)
                    if (!this.selection && this.isHovering) {
                      this.updateTooltip({ mode: "hover", clientX: e.clientX, startMs: ms, endMs: ms });
                    } else if (this.selection && this.isHovering) {
                      // Keep selection tooltip anchored near cursor
                      this.updateTooltip({ mode: "selection", clientX: e.clientX, startMs: this.selection.startMs, endMs: this.selection.endMs });
                    }

                    this.draw();
                  };

                  this.onPointerUp = (e) => {
                    if (!this.isSelecting) return;

                    this.isSelecting = false;
                    this.waveformEl.releasePointerCapture?.(e.pointerId);

                    const durationMs = this.durationMs() || 0;
                    const r = this.ratioFromClientX(e.clientX);
                    const ms = durationMs * r;

                    if (!this.selection) {
                      this.draw();
                      return;
                    }

                    const startMs = Math.min(this.selection.startMs, this.selection.endMs);
                    const endMs = Math.max(this.selection.startMs, this.selection.endMs);
                    const selectionSeconds = (endMs - startMs) / 1000;

                    if (!this.didDrag || selectionSeconds < MIN_SELECTION_SECONDS) {
                      // Treat as click: seek + clear selection
                      this.selection = null;
                      this.hideTooltip();
                      this.seekTo(ms / 1000);
                      this.draw();
                      return;
                    }

                    // Keep selection pinned
                    this.selection.startMs = startMs;
                    this.selection.endMs = endMs;
                    this.selection.startRatio = startMs / (durationMs || 1);
                    this.selection.endRatio = endMs / (durationMs || 1);

                    this.updateTooltip({ mode: "selection", clientX: e.clientX, startMs: startMs, endMs: endMs });
                    this.draw();
                  };

                  this.waveformEl.addEventListener("pointerenter", this.onPointerEnter);
                  this.waveformEl.addEventListener("pointerleave", this.onPointerLeave);
                  this.waveformEl.addEventListener("pointerdown", this.onPointerDown);
                  this.waveformEl.addEventListener("pointermove", this.onPointerMove);
                  this.waveformEl.addEventListener("pointerup", this.onPointerUp);
                  this.waveformEl.addEventListener("pointercancel", this.onPointerUp);

                  // Keyboard seek + selection clear
                  this.onKeyDown = (e) => {
                    if (e.key === "Escape") {
                      this.selection = null;
                      this.hideTooltip();
                      this.draw();
                      return;
                    }

                    if (e.key === "ArrowLeft") {
                      e.preventDefault();
                      this.seekBy(-5);
                    } else if (e.key === "ArrowRight") {
                      e.preventDefault();
                      this.seekBy(5);
                    } else if (e.key === " " || e.key === "Enter") {
                      e.preventDefault();
                      this.onPlayClick();
                    }
                  };
                  this.waveformEl.addEventListener("keydown", this.onKeyDown);

                  // Initial UI render
                  this.updateDurationUI();
                  this.updateTimeUI();
                  this.updatePlayUI();
                  this.updateActiveTranscript();
                  this.draw();

                  // Best-effort: download into a Blob URL so seeking is reliable + enables real waveform (if decode succeeds)
                  this.abortController = new AbortController();
                  this.enhanceFromRemote().catch(() => {});
                },

                updated() {
                  // LiveView patches can replace transcript nodes; keep highlighting reliable.
                  this.refreshTranscriptIndex?.();
                },

                destroyed() {
                  if (this.transcriptRoot) this.transcriptRoot.removeEventListener("click", this.onTranscriptClick);
                  try {
                    if (this.resizeObserver) this.resizeObserver.disconnect();
                  } catch (_e) {}

                  this.stopAnimationLoop?.();
                  if (this.abortController) {
                    try { this.abortController.abort(); } catch (_e) {}
                  }

                  if (this.audioEl) {
                    this.audioEl.removeEventListener("loadedmetadata", this.onLoadedMetadata);
                    this.audioEl.removeEventListener("timeupdate", this.onTimeUpdate);
                    this.audioEl.removeEventListener("play", this.onPlayPause);
                    this.audioEl.removeEventListener("pause", this.onPlayPause);
                    this.audioEl.removeEventListener("ended", this.onPlayPause);
                  }

                  if (this.playBtn) this.playBtn.removeEventListener("click", this.onPlayClick);
                  if (this.rateBtn) this.rateBtn.removeEventListener("click", this.onRateClick);
                  if (this.rewindBtn) this.rewindBtn.removeEventListener("click", this.onRewindClick);
                  if (this.forwardBtn) this.forwardBtn.removeEventListener("click", this.onForwardClick);

                  if (this.waveformEl) {
                    this.waveformEl.removeEventListener("pointerenter", this.onPointerEnter);
                    this.waveformEl.removeEventListener("pointerleave", this.onPointerLeave);
                    this.waveformEl.removeEventListener("pointerdown", this.onPointerDown);
                    this.waveformEl.removeEventListener("pointermove", this.onPointerMove);
                    this.waveformEl.removeEventListener("pointerup", this.onPointerUp);
                    this.waveformEl.removeEventListener("pointercancel", this.onPointerUp);
                    this.waveformEl.removeEventListener("keydown", this.onKeyDown);
                  }

                  if (this.objectUrl) {
                    try { URL.revokeObjectURL(this.objectUrl); } catch (_e) {}
                    this.objectUrl = null;
                  }
                },

                getDuration() {
                  const d = this.audioEl?.duration;
                  if (Number.isFinite(d) && d > 0) return d;

                  if (this.datasetDuration > 0) return this.datasetDuration;
                  if (this.datasetDurationMs > 0) return this.datasetDurationMs / 1000;
                  if (this.timelineDurationMs > 0) return this.timelineDurationMs / 1000;
                  if (this.maxContextMs > 0) return this.maxContextMs / 1000;

                  return 0;
                },

                updateDurationUI() {
                  const duration = this.getDuration();
                  if (this.totalTimeEl) this.totalTimeEl.textContent = formatTime(duration);
                  this.waveformEl?.setAttribute("aria-valuemax", String(Math.floor(duration)));
                },

                updateTimeUI() {
                  const current = this.audioEl?.currentTime || 0;
                  if (this.currentTimeEl) this.currentTimeEl.textContent = formatTime(current);
                  this.waveformEl?.setAttribute("aria-valuenow", String(Math.floor(current)));
                },

                updatePlayUI() {
                  const isPlaying = this.audioEl && !this.audioEl.paused && !this.audioEl.ended;
                  const playIcon = this.playBtn?.querySelector(".js-play-icon");
                  const pauseIcon = this.playBtn?.querySelector(".js-pause-icon");

                  if (playIcon) playIcon.classList.toggle("hidden", !!isPlaying);
                  if (pauseIcon) pauseIcon.classList.toggle("hidden", !isPlaying);

                  // Toggle playing state class for pulse animation
                  if (this.playBtn) {
                    this.playBtn.classList.toggle("is-playing", !!isPlaying);
                  }

                  return isPlaying;
                },

                updateActiveTranscript() {
                  if (!this.transcriptMeta || this.transcriptMeta.length === 0) return;

                  const isPlaying = this.audioEl && !this.audioEl.paused && !this.audioEl.ended;

                  // Clear highlight when paused
                  if (!isPlaying) {
                    if (this.activeTranscriptEl) {
                      this.activeTranscriptEl.classList.remove("swati-active-transcript");
                      this.activeTranscriptEl = null;
                    }
                    return;
                  }

                  const currentMs = (this.audioEl?.currentTime || 0) * 1000;

                  // Prefer: (1) items that contain currentMs, (2) tool items over message items, (3) most specific (shortest duration)
                  let best = null;

                  for (const item of this.transcriptMeta) {
                    if (item.start > currentMs) break;

                    const contains = currentMs >= item.start && currentMs <= item.end;
                    if (!contains) continue;

                    if (!best) {
                      best = item;
                      continue;
                    }

                    const bestIsTool = best.type === "tool";
                    const itemIsTool = item.type === "tool";

                    if (itemIsTool && !bestIsTool) {
                      best = item;
                      continue;
                    }

                    if (itemIsTool === bestIsTool) {
                      if (item.dur < best.dur) best = item;
                      else if (item.dur === best.dur && item.start > best.start) best = item;
                    }
                  }

                  if (!best) {
                    // Fallback: keep last-started transcript item highlighted (prevents "dead zones")
                    for (const item of this.transcriptMeta) {
                      if (item.start <= currentMs) best = item;
                      else break;
                    }
                  }

                  const nextEl = best ? best.el : null;

                  if (nextEl === this.activeTranscriptEl) return;

                  if (this.activeTranscriptEl) this.activeTranscriptEl.classList.remove("swati-active-transcript");
                  this.activeTranscriptEl = nextEl;

                  if (this.activeTranscriptEl) {
                    this.activeTranscriptEl.classList.add("swati-active-transcript");
                    this.activeTranscriptEl.scrollIntoView({ behavior: "smooth", block: "nearest" });
                  }
                },

                async seekTo(timeSeconds) {
                  const duration = this.getDuration();
                  const next = clamp(timeSeconds, 0, duration);

                  try {
                    this.audioEl.currentTime = next;
                  } catch (_e) {}

                  this.updateTimeUI();
                  this.updateActiveTranscript();
                  this.draw();
                },

                seekBy(deltaSeconds) {
                  const current = this.audioEl?.currentTime || 0;
                  this.seekTo(current + deltaSeconds);
                },

                async enhanceFromRemote() {
                  if (!this.audioUrl) return;
                  if (this.objectUrl) return;

                  let res;
                  try {
                    res = await fetch(this.audioUrl, {
                      signal: this.abortController.signal,
                      credentials: "omit",
                    });
                  } catch (e) {
                    console.warn("[CallAudioPlayer] Unable to fetch audio for waveform/seek enhancement:", e);
                    return;
                  }

                  if (!res || !res.ok) return;

                  const headerType = res.headers.get("content-type");
                  const mime = guessMimeType(this.audioUrl, headerType);

                  let arrayBuffer;
                  try { arrayBuffer = await res.arrayBuffer(); } catch (_e) { return; }
                  if (this.abortController.signal.aborted) return;

                  const blob = new Blob([arrayBuffer], { type: mime });
                  const objectUrl = URL.createObjectURL(blob);

                  const keepTime = this.audioEl.currentTime || 0;
                  const wasPlaying = !this.audioEl.paused && !this.audioEl.ended;

                  try { this.audioEl.pause(); } catch (_e) {}

                  this.audioEl.src = objectUrl;
                  this.audioEl.load();

                  await waitForEvent(this.audioEl, "loadedmetadata", 2000);

                  try {
                    const duration = this.getDuration();
                    this.audioEl.currentTime = clamp(keepTime, 0, duration);
                  } catch (_e) {}

                  if (wasPlaying) {
                    try { await this.audioEl.play(); } catch (_e) {}
                  }

                  this.objectUrl = objectUrl;
                  this.updateDurationUI();
                  this.updateTimeUI();
                  this.updateActiveTranscript();

                  try {
                    const AudioCtx = window.AudioContext || window.webkitAudioContext;
                    if (!AudioCtx) throw new Error("AudioContext not available");

                    const ctx = new AudioCtx();
                    const decoded = await ctx.decodeAudioData(arrayBuffer.slice(0));
                    try { await ctx.close(); } catch (_e) {}

                    const peaks = computePeaksFromAudioBuffer(decoded, 1400);
                    if (peaks && peaks.length > 0) {
                      this.rawPeaks = peaks;
                      this.draw();
                    }
                  } catch (e) {
                    console.warn("[CallAudioPlayer] Unable to decode audio for waveform:", e);
                  }
                },

                draw() {
                  if (!this.ctx || !this.waveformEl || !this.canvasEl) return;

                  const rect = this.waveformEl.getBoundingClientRect();
                  const width = Math.max(1, rect.width);
                  const height = Math.max(1, rect.height);
                  const dpr = window.devicePixelRatio || 1;

                  const targetW = Math.floor(width * dpr);
                  const targetH = Math.floor(height * dpr);

                  if (this.canvasEl.width !== targetW || this.canvasEl.height !== targetH) {
                    this.canvasEl.width = targetW;
                    this.canvasEl.height = targetH;
                  }

                  const ctx = this.ctx;
                  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
                  ctx.clearRect(0, 0, width, height);

                  const durationMs = this.durationMs() || 0;
                  const duration = durationMs > 0 ? durationMs / 1000 : this.getDuration();
                  const progress = duration > 0 ? clamp((this.audioEl.currentTime || 0) / duration, 0, 1) : 0;

                  // Speaker background overlays
                  if (durationMs > 0 && Array.isArray(this.speakerSegments) && this.speakerSegments.length > 0) {
                    for (const seg of this.speakerSegments) {
                      const s = Number(seg?.start_ms ?? -1);
                      const e = Number(seg?.end_ms ?? -1);
                      if (s < 0 || e < 0 || e <= s) continue;

                      const speaker = normalizeSpeaker(seg?.speaker);
                      const x0 = clamp((s / durationMs) * width, 0, width);
                      const x1 = clamp((e / durationMs) * width, 0, width);
                      const w = Math.max(0, x1 - x0);

                      ctx.fillStyle = speaker === "customer" ? this.customerBg : this.agentBg;
                      ctx.fillRect(x0, 0, w, height);
                    }
                  }

                  // Selection overlay
                  if (this.selection && durationMs > 0) {
                    const s = Number(this.selection.startMs || 0);
                    const e = Number(this.selection.endMs || 0);
                    const x0 = clamp((s / durationMs) * width, 0, width);
                    const x1 = clamp((e / durationMs) * width, 0, width);
                    const w = Math.max(0, x1 - x0);

                    ctx.fillStyle = this.selectionBg;
                    ctx.fillRect(x0, 0, w, height);

                    ctx.strokeStyle = this.selectionBorder;
                    ctx.lineWidth = 1;
                    ctx.strokeRect(x0 + 0.5, 0.5, Math.max(0, w - 1), height - 1);
                  }

                  // Waveform bars
                  const barGap = 3; // dense + screenshot-like
                  const barCount = Math.max(1, Math.floor(width / barGap));
                  const peaks = resamplePeaksMax(this.rawPeaks, barCount);

                  const topPad = 2;
                  const bottomPad = 8; // leaves room for dots
                  const usableHeight = Math.max(1, height - topPad - bottomPad);
                  const centerY = topPad + usableHeight / 2;
                  const maxBar = (usableHeight / 2) * 0.98;

                  const playedBars = Math.floor(progress * barCount);

                  ctx.lineCap = "round";
                  ctx.lineWidth = 2;

                  // Base waveform
                  ctx.strokeStyle = this.baseColor;
                  ctx.beginPath();
                  for (let i = 0; i < barCount; i++) {
                    const x = i * barGap + barGap / 2;
                    const p = clamp(peaks[i] || 0, 0, 1);
                    const amp = Math.max(0.02, Math.pow(p, 1.15)); // more pronounced oscillations
                    const h = amp * maxBar;
                    ctx.moveTo(x, centerY - h);
                    ctx.lineTo(x, centerY + h);
                  }
                  ctx.stroke();

                  // Played overlay
                  if (playedBars > 0) {
                    ctx.strokeStyle = this.playedColor;
                    ctx.beginPath();
                    for (let i = 0; i < playedBars; i++) {
                      const x = i * barGap + barGap / 2;
                      const p = clamp(peaks[i] || 0, 0, 1);
                      const amp = Math.max(0.02, Math.pow(p, 1.15));
                      const h = amp * maxBar;
                      ctx.moveTo(x, centerY - h);
                      ctx.lineTo(x, centerY + h);
                    }
                    ctx.stroke();
                  }

                  // Progress line (matches screenshot feel)
                  if (duration > 0) {
                    const x = clamp(progress * width, 0, width);
                    ctx.strokeStyle = this.playedColor;
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    ctx.moveTo(x, 0);
                    ctx.lineTo(x, height);
                    ctx.stroke();
                  }

                  // Tool call dots along bottom (subtle)
                  if (durationMs > 0 && Array.isArray(this.toolCalls) && this.toolCalls.length > 0) {
                    const y = height - 3;
                    for (const t of this.toolCalls) {
                      const s = Number(t?.start_ms ?? -1);
                      if (s < 0) continue;
                      const x = clamp((s / durationMs) * width, 0, width);

                      const status = (t?.status ?? "").toString().toLowerCase();
                      if (status.includes("fail") || status.includes("error")) {
                        ctx.fillStyle = "rgba(239,68,68,0.85)";
                      } else {
                        ctx.fillStyle = "rgba(34,197,94,0.85)";
                      }

                      ctx.beginPath();
                      ctx.arc(x, y, 2, 0, Math.PI * 2);
                      ctx.fill();
                    }
                  }

                  // Hover line (only if no selection pinned)
                  if (!this.selection && this.isHovering && this.hoverRatio != null) {
                    const x = clamp(this.hoverRatio * width, 0, width);
                    ctx.strokeStyle = this.hoverLineColor;
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(x, 0);
                    ctx.lineTo(x, height);
                    ctx.stroke();
                  }
                },
              };
            </script>

            <script :type={Phoenix.LiveView.ColocatedHook} name=".ToolJsonFormatter">
              const MAX_PARSE_DEPTH = 3;
              const MAX_NORMALIZE_DEPTH = 4;

              const looksLikeJson = (value) => {
                if (!value) return false;
                const first = value[0];
                return first === "{" || first === "[" || first === "\"";
              };

              const decodeEscapedJsonString = (value) => {
                if (!value.includes("\\\"")) return null;

                try {
                  const escaped = value.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
                  return JSON.parse(`"${escaped}"`);
                } catch (_e) {
                  return null;
                }
              };

              const parseJsonValue = (raw) => {
                if (typeof raw !== "string") return null;

                let value = raw.trim();
                if (value === "") return null;

                let depth = 0;
                while (depth < MAX_PARSE_DEPTH) {
                  if (!looksLikeJson(value)) return null;

                  try {
                    const parsed = JSON.parse(value);
                    if (typeof parsed === "string") {
                      value = parsed.trim();
                      depth += 1;
                      continue;
                    }
                    return parsed;
                  } catch (_e) {
                    const unescaped = decodeEscapedJsonString(value);
                    if (typeof unescaped === "string") {
                      value = unescaped.trim();
                      depth += 1;
                      continue;
                    }
                    return null;
                  }
                }

                return null;
              };

              const normalizeJsonStrings = (value, depth = 0) => {
                if (depth > MAX_NORMALIZE_DEPTH) return value;

                if (Array.isArray(value)) {
                  return value.map((entry) => normalizeJsonStrings(entry, depth + 1));
                }

                if (value && typeof value === "object") {
                  return Object.fromEntries(
                    Object.entries(value).map(([key, val]) => [
                      key,
                      normalizeJsonStrings(val, depth + 1),
                    ]),
                  );
                }

                if (typeof value === "string") {
                  const parsed = parseJsonValue(value);
                  if (parsed) {
                    return normalizeJsonStrings(parsed, depth + 1);
                  }
                }

                return value;
              };

              const formatJsonText = (raw) => {
                const parsed = parseJsonValue(raw);
                if (!parsed || typeof parsed !== "object") return raw;

                const normalized = normalizeJsonStrings(parsed);

                try {
                  return JSON.stringify(normalized, null, 2);
                } catch (_e) {
                  return raw;
                }
              };

              export default {
                mounted() {
                  this.format();
                },

                updated() {
                  this.format();
                },

                format() {
                  const targets = this.el.querySelectorAll("[data-json-pre]");
                  targets.forEach((el) => {
                    const raw = el.textContent || "";
                    const formatted = formatJsonText(raw);
                    if (formatted && formatted !== raw) {
                      el.textContent = formatted;
                    }
                  });
                },
              };
            </script>
          </section>

          <section class="space-y-5">
            <div class="flex items-center justify-between">
              <h3 class="text-[15px] font-semibold text-foreground tracking-[-0.01em]">
                Conversation transcript
              </h3>
              <span class="text-[12px] text-foreground-softer tabular-nums">
                {length(@transcript_items)} messages
              </span>
            </div>
            <div id="transcription-panel" class="space-y-5">
              <div id="transcript-list" phx-hook=".ToolJsonFormatter" class="space-y-4">
                <%= if @transcript_items == [] do %>
                  <div class="flex flex-col items-center justify-center py-12 text-center">
                    <.icon
                      name="hero-chat-bubble-left-ellipsis"
                      class="size-10 text-foreground-softer/40 mb-3"
                    />
                    <p class="text-sm text-foreground-soft">No transcription events yet.</p>
                    <p class="text-xs text-foreground-softer mt-1">
                      Transcript will appear here once the conversation starts.
                    </p>
                  </div>
                <% else %>
                  <div :for={item <- @transcript_items} id={item_dom_id(item)}>
                    <%= if item.type == :message do %>
                      <div class={[
                        "flex gap-3",
                        item.role == :caller && "justify-end"
                      ]}>
                        <div
                          data-transcript-item="message"
                          data-start-ms={item.start_ms || 0}
                          data-end-ms={item.end_ms || item.start_ms || 0}
                          data-speaker={if(item.role == :caller, do: "customer", else: "agent")}
                          class={[
                            "max-w-[78%] md:max-w-[72%] rounded-[1.25rem] px-4 py-3.5 cursor-pointer",
                            item.role == :caller &&
                              "bg-gradient-to-br from-base-100 to-base-100/95 border border-base-300/80 text-foreground shadow-[0_1px_2px_rgba(0,0,0,0.04),0_2px_8px_-2px_rgba(0,0,0,0.06)]",
                            item.role == :agent &&
                              "bg-gradient-to-br from-base-200/90 to-base-200/70 text-foreground shadow-[0_1px_2px_rgba(0,0,0,0.03)]"
                          ]}
                        >
                          <p class="text-[14px] leading-relaxed tracking-[-0.005em]">{item.text}</p>
                          <div class="mt-2.5 flex items-center gap-2 text-[11px] text-foreground-softer">
                            <span
                              class="inline-block size-1.5 rounded-full"
                              style={
                                if item.role == :caller,
                                  do: "background-color: #a855f7",
                                  else: "background-color: #2563eb"
                              }
                            >
                            </span>
                            <span class="uppercase tracking-wider font-medium">{item.label}</span>
                            <span class="text-foreground-softer/50">·</span>
                            <span class="font-mono tabular-nums">{item.offset}</span>
                          </div>
                        </div>
                      </div>
                    <% else %>
                      <div
                        data-transcript-item="tool"
                        data-start-ms={item.start_ms || 0}
                        data-end-ms={item.end_ms || item.start_ms || 0}
                        data-speaker="tool"
                        class="rounded-[1.25rem] border border-base-300/70 bg-gradient-to-b from-base-100 to-base-100/95 p-4 shadow-[0_1px_2px_rgba(0,0,0,0.03),0_2px_8px_-2px_rgba(0,0,0,0.05)] space-y-3"
                      >
                        <div class="flex flex-wrap items-center justify-between gap-3">
                          <div class="flex items-center gap-2.5">
                            <div class={[
                              "flex items-center justify-center size-7 rounded-lg",
                              item.status == "succeeded" && "bg-success/10",
                              item.status == "failed" && "bg-danger/10"
                            ]}>
                              <.icon
                                name={
                                  if item.status == "succeeded",
                                    do: "hero-wrench-screwdriver",
                                    else: "hero-exclamation-triangle"
                                }
                                class={"size-4 #{if item.status == "succeeded", do: "text-success", else: "text-danger"}"}
                              />
                            </div>
                            <div>
                              <p class="text-[13px] font-semibold text-foreground leading-tight">
                                {item.name}
                              </p>
                              <p class="text-[11px] text-foreground-softer capitalize">
                                {item.status}
                              </p>
                            </div>
                          </div>
                          <div class="flex items-center gap-2 text-[11px] text-foreground-softer">
                            <span class="font-mono tabular-nums">{item.offset}</span>
                            <span class="text-foreground-softer/50">·</span>
                            <span class="font-mono tabular-nums">{item.duration_ms}ms</span>
                          </div>
                        </div>

                        <.accordion
                          id={"tool-accordion-#{item.id}"}
                          class="rounded-xl border border-base-200/80 overflow-hidden"
                        >
                          <.accordion_item>
                            <:header class="flex items-center justify-between gap-3 text-[13px] font-medium text-foreground bg-base-200/30 px-3.5 py-2.5">
                              <div class="flex items-center gap-2">
                                <.icon
                                  name="hero-command-line"
                                  class="size-3.5 text-foreground-softer"
                                />
                                <span>MCP call details</span>
                              </div>
                              <.icon
                                name="hero-chevron-down"
                                class="swati-accordion-chevron size-4 text-foreground-softer"
                              />
                            </:header>
                            <:panel>
                              <div class="p-3.5 space-y-4 text-xs text-foreground-soft bg-base-200/15">
                                <div class="flex items-center justify-between">
                                  <span class="uppercase tracking-wider text-[10px] font-medium text-foreground-softer">
                                    MCP server
                                  </span>
                                  <.badge size="xs" variant="surface" class="font-mono">
                                    {item.mcp_server}
                                  </.badge>
                                </div>

                                <div class="rounded-lg border border-base-200/80 bg-base-200/40 p-3 space-y-2">
                                  <p class="text-[10px] uppercase tracking-wider font-medium text-foreground-softer">
                                    Invokes
                                  </p>
                                  <pre
                                    id={"tool-invokes-#{item.id}"}
                                    data-json-pre
                                    phx-no-curly-interpolation
                                    class="swati-code-block whitespace-pre-wrap text-foreground"
                                  ><%= tool_detail_text(item.invokes || item.args) %></pre>
                                </div>

                                <div class="rounded-lg border border-base-200/80 bg-base-200/40 p-3 space-y-2">
                                  <div class="flex items-center justify-between">
                                    <p class="text-[10px] uppercase tracking-wider font-medium text-foreground-softer">
                                      Results
                                    </p>
                                    <.button
                                      variant="ghost"
                                      size="icon-xs"
                                      class="size-6 rounded-md hover:bg-base-200"
                                    >
                                      <.icon name="hero-clipboard" class="size-3.5" />
                                    </.button>
                                  </div>
                                  <pre
                                    id={"tool-results-#{item.id}"}
                                    data-json-pre
                                    phx-no-curly-interpolation
                                    class="swati-code-block whitespace-pre-wrap text-foreground"
                                  ><%= tool_detail_text(item.results || item.response) %></pre>
                                </div>
                              </div>
                            </:panel>
                          </.accordion_item>
                        </.accordion>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          </section>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant_id = socket.assigns.current_scope.tenant.id
    call = Calls.get_call!(tenant_id, id)
    timeline = Calls.get_call_timeline(tenant_id, id)

    {:ok, assign(socket, detail_assigns(call, timeline))}
  end

  def detail_assigns(call, timeline) do
    events = call.events || []
    agent_label = agent_name(call)
    status_badge = status_badge(call.status)

    transcript_items =
      if timeline_present?(timeline) do
        build_transcript_items_from_timeline(timeline, agent_label)
      else
        build_transcript_items(events, call.started_at, agent_label)
      end

    waveform_context = build_waveform_context(call, timeline, transcript_items, agent_label)

    %{
      call: call,
      primary_audio_url: primary_audio_url(call),
      agent_name: agent_label,
      status_badge: status_badge,
      transcript_items: transcript_items,
      waveform_context_json: Jason.encode!(waveform_context),
      waveform_duration_ms: waveform_context.duration_ms
    }
  end

  defp primary_audio_url(call) do
    recording = call.recording || %{}
    map_value(recording, "stereo_url", :stereo_url)
  end

  defp map_value(map, string_key, atom_key) when is_map(map) do
    Map.get(map, string_key) || Map.get(map, atom_key)
  end

  defp status_badge(status) do
    case normalize_string(status) do
      "ended" -> %{label: "Successful", color: "success"}
      "cancelled" -> %{label: "Cancelled", color: "warning"}
      "error" -> %{label: "Failed", color: "danger"}
      "failed" -> %{label: "Failed", color: "danger"}
      "started" -> %{label: "In progress", color: "info"}
      _ -> %{label: "Unknown", color: "info"}
    end
  end

  defp agent_name(call) do
    case call.agent do
      nil -> "Assistant"
      agent -> agent.name
    end
  end

  defp format_long_datetime(nil, _tenant), do: "—"

  defp format_long_datetime(%DateTime{} = dt, tenant) do
    SwatiWeb.Formatting.datetime_long(dt, tenant)
  end

  defp format_duration(nil), do: "0:00"

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    remaining = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(remaining), 2, "0")}"
  end

  defp timeline_present?(%{utterances: u, speaker_segments: s, tool_calls: t})
       when is_list(u) and is_list(s) and is_list(t) do
    u != [] or s != [] or t != []
  end

  defp timeline_present?(_), do: false

  defp normalize_speaker(nil), do: "agent"

  defp normalize_speaker(value) do
    v = value |> to_string() |> String.downcase()

    cond do
      v in ["agent", "assistant", "bot"] -> "agent"
      v in ["caller", "customer", "user"] -> "customer"
      true -> v
    end
  end

  defp truncate_text(text, max) do
    str = to_string(text || "")

    if String.length(str) <= max do
      str
    else
      String.slice(str, 0, max - 1) <> "…"
    end
  end

  # // REPOMARK:SCOPE: 3 - Add helpers to infer missing end_ms for timeline ranges and render full tool payloads (fixes "dead zones" + incomplete speaker backgrounds)
  defp timeline_duration_ms(timeline) do
    meta = if is_map(timeline), do: Map.get(timeline, :meta), else: nil
    duration = if is_map(meta), do: Map.get(meta, :duration_ms), else: nil
    if is_integer(duration) && duration > 0, do: duration, else: 0
  end

  defp safe_ms(value) when is_integer(value), do: max(value, 0)
  defp safe_ms(_), do: 0

  defp cap_ms(value, total_ms) when is_integer(total_ms) and total_ms > 0,
    do: min(value, total_ms)

  defp cap_ms(value, _), do: value

  defp estimate_timeline_duration_ms(utterances, tool_calls, speaker_segments \\ []) do
    Enum.concat([utterances, tool_calls, speaker_segments])
    |> Enum.map(fn item ->
      start = safe_ms(Map.get(item, :start_ms))
      explicit_end = safe_ms(Map.get(item, :end_ms))

      dur =
        max(
          safe_ms(Map.get(item, :latency_ms)),
          safe_ms(Map.get(item, :duration_ms))
        )

      max(explicit_end, start + dur)
    end)
    |> Enum.max(fn -> 0 end)
  end

  defp infer_end_ms(
         start_ms,
         explicit_end_ms,
         duration_ms,
         next_start_ms,
         total_duration_ms,
         opts \\ []
       ) do
    start_ms = safe_ms(start_ms)
    explicit_end_ms = safe_ms(explicit_end_ms)
    duration_ms = safe_ms(duration_ms)
    next_start_ms = safe_ms(next_start_ms)
    total_duration_ms = safe_ms(total_duration_ms)

    min_len_ms = Keyword.get(opts, :min_len_ms, 200)
    allow_next_start = Keyword.get(opts, :allow_next_start, true)
    allow_total_duration = Keyword.get(opts, :allow_total_duration, true)

    candidate =
      cond do
        explicit_end_ms > start_ms ->
          explicit_end_ms

        duration_ms > 0 ->
          start_ms + duration_ms

        allow_next_start && next_start_ms > start_ms ->
          next_start_ms

        allow_total_duration && total_duration_ms > start_ms ->
          total_duration_ms

        true ->
          start_ms
      end

    candidate
    |> max(start_ms + min_len_ms)
    |> cap_ms(total_duration_ms)
    |> max(start_ms)
  end

  defp with_inferred_end_ms(items, total_duration_ms, duration_field, opts \\ []) do
    sorted =
      items
      |> Enum.sort_by(fn item -> safe_ms(Map.get(item, :start_ms)) end, :asc)

    Enum.with_index(sorted)
    |> Enum.map(fn {item, idx} ->
      start_ms = safe_ms(Map.get(item, :start_ms))
      explicit_end_ms = Map.get(item, :end_ms)
      duration_ms = safe_ms(Map.get(item, duration_field))

      next_start_ms =
        case Enum.at(sorted, idx + 1) do
          nil -> nil
          next -> Map.get(next, :start_ms)
        end

      end_ms =
        infer_end_ms(
          start_ms,
          explicit_end_ms,
          duration_ms,
          next_start_ms,
          total_duration_ms,
          opts
        )

      {item, start_ms, end_ms}
    end)
  end

  defp inspect_full(term) do
    inspect(term, pretty: true, limit: :infinity, printable_limit: :infinity, width: 120)
  end

  defp tool_call_response_text_from_timeline(t) do
    resp =
      Map.get(t, :response) ||
        Map.get(t, :response_text) ||
        Map.get(t, :raw_response) ||
        Map.get(t, :result) ||
        Map.get(t, :output)

    cond do
      is_binary(resp) ->
        resp

      is_map(resp) or is_list(resp) ->
        inspect_full(resp)

      true ->
        to_string(Map.get(t, :response_summary) || "")
    end
  end

  defp build_transcript_items_from_timeline(timeline, agent_label) do
    utterances = Map.get(timeline, :utterances) || []
    tool_calls = Map.get(timeline, :tool_calls) || []

    # // REPOMARK:SCOPE: 4 - Infer end_ms for timeline utterances/tool_calls and show full tool args/response in transcript items
    total_duration_ms =
      case timeline_duration_ms(timeline) do
        d when is_integer(d) and d > 0 -> d
        _ -> estimate_timeline_duration_ms(utterances, tool_calls)
      end

    utter_items =
      utterances
      |> with_inferred_end_ms(total_duration_ms, :duration_ms,
        allow_next_start: true,
        allow_total_duration: true
      )
      |> Enum.map(fn {u, start_ms, end_ms} ->
        role =
          case normalize_speaker(Map.get(u, :speaker)) do
            "customer" -> :caller
            _ -> :agent
          end

        id = Map.get(u, :id) || System.unique_integer([:positive])

        %{
          id: "utt-#{id}",
          type: :message,
          role: role,
          label: if(role == :caller, do: "Customer", else: agent_label),
          text: String.trim(to_string(Map.get(u, :text) || "")),
          offset: format_duration(div(start_ms, 1000)),
          start_ms: start_ms,
          end_ms: end_ms
        }
      end)

    tool_items =
      tool_calls
      |> with_inferred_end_ms(total_duration_ms, :latency_ms,
        allow_next_start: false,
        allow_total_duration: false
      )
      |> Enum.map(fn {t, start_ms, end_ms} ->
        latency = safe_ms(Map.get(t, :latency_ms))
        duration_ms = if latency > 0, do: latency, else: max(end_ms - start_ms, 0)

        id = Map.get(t, :id) || System.unique_integer([:positive])
        invokes = extract_tool_invokes_from_timeline(t)
        results = extract_tool_results_from_timeline(t)

        %{
          id: "tool-#{id}",
          type: :tool,
          name: to_string(Map.get(t, :name) || "tool"),
          status: to_string(Map.get(t, :status) || "succeeded"),
          duration_ms: duration_ms,
          args: tool_detail_text(Map.get(t, :args)),
          invokes: invokes,
          results: results,
          response: tool_call_response_text_from_timeline(t),
          offset: format_duration(div(start_ms, 1000)),
          start_ms: start_ms,
          end_ms: end_ms,
          mcp_server: to_string(Map.get(t, :mcp_endpoint) || "mcp_server")
        }
      end)

    (utter_items ++ tool_items)
    |> Enum.sort_by(& &1.start_ms, :asc)
    |> Enum.with_index()
    |> Enum.map(fn {item, index} -> Map.put(item, :dom_index, index) end)
  end

  defp build_waveform_context(call, timeline, transcript_items, agent_label) do
    duration_ms =
      cond do
        timeline_present?(timeline) &&
          is_map(timeline) &&
          is_map(Map.get(timeline, :meta)) &&
          is_integer(timeline.meta.duration_ms) &&
            timeline.meta.duration_ms > 0 ->
          timeline.meta.duration_ms

        is_integer(call.duration_seconds) && call.duration_seconds > 0 ->
          call.duration_seconds * 1000

        true ->
          transcript_items
          |> Enum.map(&Map.get(&1, :end_ms, 0))
          |> Enum.max(fn -> 0 end)
      end

    # // REPOMARK:SCOPE: 5 - Infer end_ms for timeline speaker_segments/utterances/tool_calls so waveform shading + hover + highlights cover all regions
    speaker_segments =
      cond do
        timeline_present?(timeline) && is_list(timeline.speaker_segments) &&
            timeline.speaker_segments != [] ->
          timeline.speaker_segments
          |> with_inferred_end_ms(duration_ms, :duration_ms,
            allow_next_start: true,
            allow_total_duration: true
          )
          |> Enum.map(fn {s, start_ms, end_ms} ->
            %{
              speaker: normalize_speaker(Map.get(s, :speaker)),
              start_ms: start_ms,
              end_ms: end_ms
            }
          end)

        true ->
          derive_speaker_segments_from_items(transcript_items)
      end

    utterances =
      cond do
        timeline_present?(timeline) && is_list(timeline.utterances) && timeline.utterances != [] ->
          timeline.utterances
          |> with_inferred_end_ms(duration_ms, :duration_ms,
            allow_next_start: true,
            allow_total_duration: true
          )
          |> Enum.map(fn {u, start_ms, end_ms} ->
            %{
              speaker: normalize_speaker(Map.get(u, :speaker)),
              start_ms: start_ms,
              end_ms: end_ms,
              text: truncate_text(Map.get(u, :text) || "", 600)
            }
          end)

        true ->
          transcript_items
          |> Enum.filter(&(&1.type == :message))
          |> Enum.map(fn item ->
            %{
              speaker: if(item.role == :caller, do: "customer", else: "agent"),
              start_ms: Map.get(item, :start_ms, 0),
              end_ms: Map.get(item, :end_ms, Map.get(item, :start_ms, 0)),
              text: truncate_text(Map.get(item, :text, ""), 600)
            }
          end)
      end

    tool_calls =
      cond do
        timeline_present?(timeline) && is_list(timeline.tool_calls) && timeline.tool_calls != [] ->
          timeline.tool_calls
          |> with_inferred_end_ms(duration_ms, :latency_ms,
            allow_next_start: false,
            allow_total_duration: false
          )
          |> Enum.map(fn {t, start_ms, end_ms} ->
            %{
              name: to_string(Map.get(t, :name) || "tool"),
              status: to_string(Map.get(t, :status) || "succeeded"),
              start_ms: start_ms,
              end_ms: end_ms,
              latency_ms: safe_ms(Map.get(t, :latency_ms)),
              response_summary: truncate_text(tool_call_response_text_from_timeline(t), 420)
            }
          end)

        true ->
          transcript_items
          |> Enum.filter(&(&1.type == :tool))
          |> Enum.map(fn item ->
            %{
              name: to_string(Map.get(item, :name, "tool")),
              status: to_string(Map.get(item, :status, "succeeded")),
              start_ms: Map.get(item, :start_ms, 0),
              end_ms: Map.get(item, :end_ms, Map.get(item, :start_ms, 0)),
              latency_ms: Map.get(item, :duration_ms, 0),
              response_summary: truncate_text(Map.get(item, :response, ""), 420)
            }
          end)
      end

    markers =
      if timeline_present?(timeline) && is_list(timeline.markers) do
        Enum.map(timeline.markers, fn m ->
          %{
            kind: to_string(m.kind || "marker"),
            offset_ms: m.offset_ms || 0,
            payload: m.payload || %{}
          }
        end)
      else
        []
      end

    %{
      duration_ms: duration_ms,
      agent_label: agent_label,
      customer_label: "Customer",
      speaker_segments: speaker_segments,
      utterances: utterances,
      tool_calls: tool_calls,
      markers: markers
    }
  end

  defp derive_speaker_segments_from_items(items) do
    items
    |> Enum.filter(&(&1.type == :message))
    |> Enum.sort_by(&Map.get(&1, :start_ms, 0), :asc)
    |> Enum.reduce([], fn item, acc ->
      speaker = if item.role == :caller, do: "customer", else: "agent"
      start_ms = Map.get(item, :start_ms, 0)
      end_ms = Map.get(item, :end_ms, start_ms)

      case acc do
        [%{speaker: ^speaker, end_ms: prev_end} = last | rest] when start_ms <= prev_end + 300 ->
          [%{last | end_ms: max(prev_end, end_ms)} | rest]

        _ ->
          [%{speaker: speaker, start_ms: start_ms, end_ms: end_ms} | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp diff_ms(nil, _ts), do: 0
  defp diff_ms(_start, nil), do: 0

  defp diff_ms(%DateTime{} = start, %DateTime{} = ts) do
    max(DateTime.diff(ts, start, :millisecond), 0)
  end

  defp build_transcript_items(events, started_at, agent_label) do
    {items, current, _tool_calls} =
      Enum.reduce(events, {[], nil, %{}}, fn event, {items, current, tool_calls} ->
        case event.type do
          "transcript" ->
            payload = event.payload || %{}
            tag = normalize_string(map_value(payload, "tag", :tag))
            text = map_value(payload, "text", :text) || ""

            if text == "" do
              {items, current, tool_calls}
            else
              case current do
                %{tag: ^tag} = entry ->
                  {items, %{entry | text: append_text(entry.text, text), end_ts: event.ts},
                   tool_calls}

                _ ->
                  {items, _current} = flush_current(items, current, started_at, agent_label)

                  {items, %{tag: tag, text: text, start_ts: event.ts, end_ts: event.ts},
                   tool_calls}
              end
            end

          "tool_call" ->
            payload = event.payload || %{}
            id = map_value(payload, "id", :id)

            payload = Map.put(payload, "_event_ts", event.ts)

            {items, current, Map.put(tool_calls, id, payload)}

          "tool_result" ->
            payload = event.payload || %{}
            id = map_value(payload, "id", :id)
            {items, current} = flush_current(items, current, started_at, agent_label)

            tool_item =
              build_tool_item(
                id,
                tool_calls,
                payload,
                started_at,
                event.ts
              )

            {[tool_item | items], current, Map.delete(tool_calls, id)}

          _ ->
            {items, current, tool_calls}
        end
      end)

    {items, _current} = flush_current(items, current, started_at, agent_label)

    items
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.map(fn {item, index} -> Map.put(item, :dom_index, index) end)
  end

  defp build_tool_item(id, tool_calls, payload, started_at, ts) do
    call_payload = Map.get(tool_calls, id, %{})
    name = map_value(payload, "name", :name) || map_value(call_payload, "name", :name) || "tool"
    args = map_value(call_payload, "args", :args)
    duration_ms = map_value(payload, "ms", :ms) || 0
    status = if map_value(payload, "isError", :isError), do: "failed", else: "succeeded"
    invokes = tool_invoke_payload(call_payload)
    results = tool_result_payload(payload)

    # // REPOMARK:SCOPE: 6 - Show full tool args/response (avoid truncation) for non-timeline tool_call/tool_result event path
    call_ts = Map.get(call_payload, "_event_ts") || Map.get(call_payload, :_event_ts)

    start_ms =
      cond do
        is_struct(call_ts, DateTime) ->
          diff_ms(started_at, call_ts)

        is_integer(duration_ms) && duration_ms > 0 ->
          max(diff_ms(started_at, ts) - duration_ms, 0)

        true ->
          diff_ms(started_at, ts)
      end

    end_ms = start_ms + (duration_ms || 0)

    %{
      id: id || "tool-#{System.unique_integer([:positive])}",
      type: :tool,
      name: name,
      status: status,
      duration_ms: duration_ms,
      args: tool_detail_text(args),
      invokes: invokes,
      results: results,
      response: tool_response_text(payload),
      offset: format_duration(div(start_ms, 1000)),
      start_ms: start_ms,
      end_ms: end_ms,
      mcp_server: "mcp_server"
    }
  end

  defp tool_response_text(payload) do
    response = map_value(payload, "response", :response) || %{}
    content = map_value(response, "content", :content) || []

    texts =
      content
      |> Enum.map(fn
        %{"text" => text} when is_binary(text) -> text
        %{text: text} when is_binary(text) -> text
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    case texts do
      [text] -> text
      [_ | _] -> Enum.join(texts, "\n\n")
      [] -> inspect_full(response)
    end
  end

  defp flush_current(items, nil, _started_at, _agent_label), do: {items, nil}

  defp flush_current(items, current, started_at, agent_label) do
    role =
      case current.tag do
        "caller" -> :caller
        "agent" -> :agent
        _ -> :agent
      end

    start_ms = diff_ms(started_at, Map.get(current, :start_ts))
    end_ms = diff_ms(started_at, Map.get(current, :end_ts))

    item = %{
      id: "msg-#{System.unique_integer([:positive])}",
      type: :message,
      role: role,
      label: if(role == :caller, do: "Customer", else: agent_label),
      text: String.trim(current.text),
      offset: format_duration(div(start_ms, 1000)),
      start_ms: start_ms,
      end_ms: max(end_ms, start_ms)
    }

    {[item | items], nil}
  end

  defp append_text(existing, next) do
    existing = String.trim(existing || "")
    next = String.trim(next || "")

    if existing == "" do
      next
    else
      existing <> " " <> next
    end
  end

  defp normalize_string(nil), do: ""
  defp normalize_string(value) when is_binary(value), do: String.downcase(value)
  defp normalize_string(value), do: value |> to_string() |> String.downcase()

  defp tool_detail_text(value) do
    cond do
      is_nil(value) ->
        "—"

      is_binary(value) ->
        text = String.trim(value)
        if text == "", do: "—", else: text

      is_map(value) or is_list(value) ->
        case Jason.encode(value) do
          {:ok, encoded} ->
            text = String.trim(encoded)
            if text == "", do: "—", else: text

          _ ->
            inspect_full(value)
        end

      true ->
        to_string(value)
    end
  end

  defp tool_invoke_payload(payload) when is_map(payload) do
    Map.drop(payload, ["_event_ts", :_event_ts])
  end

  defp tool_invoke_payload(payload), do: payload

  defp tool_result_payload(payload), do: payload

  defp fetch_first_value(map, keys) when is_map(map) do
    Enum.find_value(keys, fn key ->
      value = Map.get(map, key)
      if is_nil(value), do: Map.get(map, to_string(key)), else: value
    end)
  end

  defp fetch_first_value(_map, _keys), do: nil

  defp extract_tool_invokes_from_timeline(t) do
    fetch_first_value(t, [
      :invokes,
      :invocations,
      :invoke,
      :invocation,
      :request,
      :args,
      :parameters,
      :params,
      :input
    ])
  end

  defp extract_tool_results_from_timeline(t) do
    fetch_first_value(t, [
      :results,
      :result,
      :response,
      :response_text,
      :raw_response,
      :output,
      :response_summary
    ])
  end

  defp item_dom_id(%{type: :message, dom_index: index}), do: "transcript-item-#{index}"
  defp item_dom_id(%{type: :tool, dom_index: index}), do: "tool-item-#{index}"
end
