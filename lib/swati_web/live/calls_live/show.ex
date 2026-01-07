defmodule SwatiWeb.CallsLive.Show do
  use SwatiWeb, :live_view

  alias Swati.Calls

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.call_detail
        call={@call}
        events={@events}
        active_tab={@active_tab}
        primary_audio_url={@primary_audio_url}
        agent_name={@agent_name}
        status_badge={@status_badge}
        summary_text={@summary_text}
        metadata={@metadata}
        client_data={@client_data}
        transcript_items={@transcript_items}
        back_patch={~p"/calls"}
      />
    </Layouts.app>
    """
  end

  attr :call, :map, required: true
  attr :events, :list, required: true
  attr :active_tab, :string, required: true
  attr :primary_audio_url, :string, default: nil
  attr :agent_name, :string, required: true
  attr :status_badge, :map, required: true
  attr :summary_text, :string, required: true
  attr :metadata, :map, required: true
  attr :client_data, :map, required: true
  attr :transcript_items, :list, required: true
  attr :back_patch, :string, default: nil

  def call_detail(assigns) do
    ~H"""
    <div id="call-detail" class="space-y-8 font-['Instrument_Sans']">
      <header class="flex flex-wrap items-start gap-4">
        <div class="space-y-2">
          <div class="flex flex-wrap items-center gap-3">
            <h1 class="text-2xl md:text-3xl font-semibold text-foreground font-['Instrument_Serif']">
              Conversation with {@agent_name}
            </h1>
            <.badge size="sm" variant="soft" color={@status_badge.color}>
              {@status_badge.label}
            </.badge>
          </div>
          <div class="flex flex-wrap items-center gap-3 text-sm text-foreground-soft">
            <span>{@call.from_number} → {@call.to_number}</span>
            <span class="text-foreground-softer">•</span>
            <span class="font-mono text-xs text-foreground-softer">{@call.id}</span>
          </div>
        </div>
        <div class="ml-auto flex items-center gap-2">
          <.button :if={@back_patch} patch={@back_patch} variant="ghost" size="sm">
            <.icon name="hero-arrow-left" class="icon" /> Back
          </.button>
        </div>
      </header>

      <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
        <div class="space-y-6">
          <section
            id="call-audio-panel"
            phx-hook=".CallAudioPlayer"
            data-audio-url={@primary_audio_url || ""}
            data-duration={@call.duration_seconds || 0}
            data-seed={@call.id}
            class="rounded-3xl border border-base-300 bg-base-100 p-6 shadow-sm space-y-4"
          >
            <div class="flex items-start justify-between gap-4">
              <div class="space-y-1">
                <h2 class="text-lg font-semibold text-foreground">Conversation audio</h2>
                <p class="text-sm text-foreground-soft">
                  {format_long_datetime(@call.started_at)}
                  <span class="text-foreground-softer">·</span>
                  {format_duration(@call.duration_seconds)}
                </p>
              </div>
              <div class="flex items-center gap-2">
                <.button variant="ghost" size="icon-sm">
                  <.icon name="hero-arrow-down-tray" class="icon" />
                </.button>
                <.button variant="ghost" size="icon-sm">
                  <.icon name="hero-ellipsis-horizontal" class="icon" />
                </.button>
              </div>
            </div>

            <%= if @primary_audio_url do %>
              <div
                id="call-waveform-container"
                class="call-waveform h-12 rounded-full bg-base-200/70"
                phx-update="ignore"
                role="slider"
                tabindex="0"
                aria-label="Audio seek bar"
                aria-valuemin="0"
                aria-valuemax={@call.duration_seconds || 0}
                aria-valuenow="0"
              >
                <canvas id="call-waveform" class="call-waveform-canvas"></canvas>
              </div>

              <div class="flex flex-wrap items-center gap-4">
                <.button id="call-audio-play" size="icon" variant="solid" color="primary">
                  <.icon name="hero-play" class="icon js-play-icon" />
                  <.icon name="hero-pause" class="icon js-pause-icon hidden" />
                </.button>

                <button
                  id="call-audio-rate"
                  type="button"
                  class="text-sm text-foreground-soft rounded-xl px-2 py-1 hover:bg-base-200 active:bg-base-200"
                >
                  1.0x
                </button>

                <div class="flex items-center gap-2">
                  <.button id="call-audio-rewind" size="icon-sm" variant="ghost">
                    <.icon name="hero-arrow-uturn-left" class="icon" />
                  </.button>
                  <.button id="call-audio-forward" size="icon-sm" variant="ghost">
                    <.icon name="hero-arrow-uturn-right" class="icon" />
                  </.button>
                </div>

                <div class="ml-auto text-sm text-foreground-soft tabular-nums">
                  <span id="call-audio-current-time">0:00</span>
                  <span class="text-foreground-softer">/</span>
                  <span id="call-audio-total-time">{format_duration(@call.duration_seconds)}</span>
                </div>
              </div>

              <audio id="call-audio" preload="metadata" src={@primary_audio_url} class="hidden">
              </audio>
            <% else %>
              <div class="text-sm text-foreground-soft">No audio recording available.</div>
            <% end %>

            <script :type={Phoenix.LiveView.ColocatedHook} name=".CallAudioPlayer">
              const RATES = [1.0, 1.25, 1.5, 2.0];
              const SEEK_STEP_SECONDS = 10;

              function clamp(n, min, max) {
                return Math.min(Math.max(n, min), max);
              }

              function formatTime(totalSeconds) {
                if (!Number.isFinite(totalSeconds) || totalSeconds < 0) return "0:00";
                const seconds = Math.floor(totalSeconds);
                const minutes = Math.floor(seconds / 60);
                const remaining = seconds % 60;
                return `${minutes}:${String(remaining).padStart(2, "0")}`;
              }

              function formatRate(rate) {
                // Match screenshot style: 1.0x, 1.25x, 1.5x, 2.0x
                if (rate === 1 || rate === 1.5 || rate === 2) return `${rate.toFixed(1)}x`;
                return `${rate.toFixed(2)}x`;
              }

              function hashStringToUint32(str) {
                // FNV-1a
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
                  // Slight smoothing so it looks like a real waveform, not pure noise
                  const smooth = prev * 0.65 + next * 0.35;
                  prev = smooth;

                  // Add occasional quieter regions
                  let amp = Math.pow(smooth, 1.6) * 0.95 + 0.05;
                  if (rand() < 0.08) amp *= 0.25;
                  peaks[i] = clamp(amp, 0.02, 1.0);
                }

                return peaks;
              }

              function resamplePeaksMax(peaks, targetCount) {
                if (!Array.isArray(peaks) || peaks.length === 0) return new Array(targetCount).fill(0.1);
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

                  this.playBtn = this.el.querySelector("#call-audio-play");
                  this.rateBtn = this.el.querySelector("#call-audio-rate");
                  this.rewindBtn = this.el.querySelector("#call-audio-rewind");
                  this.forwardBtn = this.el.querySelector("#call-audio-forward");

                  this.currentTimeEl = this.el.querySelector("#call-audio-current-time");
                  this.totalTimeEl = this.el.querySelector("#call-audio-total-time");

                  if (!this.audioEl || !this.waveformEl || !this.canvasEl) return;

                  this.audioUrl = (this.el.dataset.audioUrl || "").trim() || this.audioEl.getAttribute("src") || "";
                  this.datasetDuration = Number(this.el.dataset.duration || 0) || 0;
                  this.seed = (this.el.dataset.seed || "").toString() || this.audioUrl || "call-waveform";

                  this.ctx = this.canvasEl.getContext("2d");
                  this.baseColor = cssVar(this.waveformEl, "--waveform-color", "rgba(0,0,0,0.18)");
                  this.playedColor = cssVar(this.waveformEl, "--waveform-color-played", "rgba(0,0,0,0.34)");

                  // Start with a placeholder waveform (fast + no CORS needed)
                  this.rawPeaks = buildPlaceholderPeaks(900, this.seed);

                  // Playback rate
                  this.rateIndex = 0;
                  this.audioEl.playbackRate = RATES[this.rateIndex];
                  if (this.rateBtn) this.rateBtn.textContent = formatRate(RATES[this.rateIndex]);

                  // Resize handling
                  this.resizeObserver = new ResizeObserver(() => this.draw());
                  this.resizeObserver.observe(this.waveformEl);

                  // Audio event handlers
                  this.onLoadedMetadata = () => {
                    this.updateDurationUI();
                    this.updateTimeUI();
                    this.draw();
                  };

                  this.onTimeUpdate = () => {
                    this.updateTimeUI();
                    this.draw();
                  };

                  this.onPlayPause = () => this.updatePlayUI();

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
                    } catch (_e) {
                      // Ignore autoplay/user-gesture restrictions
                    }
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

                  // Waveform seek (click/drag)
                  this.isSeeking = false;

                  this.seekFromPointerEvent = (e) => {
                    const rect = this.waveformEl.getBoundingClientRect();
                    if (rect.width <= 0) return;

                    const ratio = clamp((e.clientX - rect.left) / rect.width, 0, 1);
                    const duration = this.getDuration();
                    const nextTime = ratio * duration;

                    this.seekTo(nextTime);
                  };

                  this.onPointerDown = (e) => {
                    if (e.button != null && e.button !== 0) return;
                    this.isSeeking = true;
                    this.waveformEl.setPointerCapture?.(e.pointerId);
                    this.seekFromPointerEvent(e);
                  };

                  this.onPointerMove = (e) => {
                    if (!this.isSeeking) return;
                    this.seekFromPointerEvent(e);
                  };

                  this.onPointerUp = (e) => {
                    this.isSeeking = false;
                    this.waveformEl.releasePointerCapture?.(e.pointerId);
                  };

                  this.waveformEl.addEventListener("pointerdown", this.onPointerDown);
                  this.waveformEl.addEventListener("pointermove", this.onPointerMove);
                  this.waveformEl.addEventListener("pointerup", this.onPointerUp);
                  this.waveformEl.addEventListener("pointercancel", this.onPointerUp);

                  // Keyboard seek (optional but useful)
                  this.onKeyDown = (e) => {
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
                  this.draw();

                  // Best-effort: download into a Blob URL so seeking is reliable even when the remote host doesn't support range requests well.
                  // This also enables a real waveform (if decode succeeds).
                  this.abortController = new AbortController();
                  this.enhanceFromRemote().catch(() => {});
                },

                destroyed() {
                  try {
                    if (this.resizeObserver) this.resizeObserver.disconnect();
                  } catch (_e) {}

                  if (this.abortController) {
                    try {
                      this.abortController.abort();
                    } catch (_e) {}
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
                    this.waveformEl.removeEventListener("pointerdown", this.onPointerDown);
                    this.waveformEl.removeEventListener("pointermove", this.onPointerMove);
                    this.waveformEl.removeEventListener("pointerup", this.onPointerUp);
                    this.waveformEl.removeEventListener("pointercancel", this.onPointerUp);
                    this.waveformEl.removeEventListener("keydown", this.onKeyDown);
                  }

                  if (this.objectUrl) {
                    try {
                      URL.revokeObjectURL(this.objectUrl);
                    } catch (_e) {}
                    this.objectUrl = null;
                  }
                },

                getDuration() {
                  const d = this.audioEl?.duration;
                  if (Number.isFinite(d) && d > 0) return d;
                  return Math.max(0, this.datasetDuration || 0);
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
                },

                async seekTo(timeSeconds) {
                  const duration = this.getDuration();
                  const next = clamp(timeSeconds, 0, duration);

                  try {
                    this.audioEl.currentTime = next;
                  } catch (_e) {
                    // Ignore
                  }

                  // If the remote host is not seekable, some browsers will refuse to move currentTime.
                  // We opportunistically swap to a Blob URL (if possible) in enhanceFromRemote().
                  // Here, we just keep UI responsive while the audio seeks.
                  this.updateTimeUI();
                  this.draw();
                },

                seekBy(deltaSeconds) {
                  const current = this.audioEl?.currentTime || 0;
                  this.seekTo(current + deltaSeconds);
                },

                async enhanceFromRemote() {
                  if (!this.audioUrl) return;
                  if (this.objectUrl) return; // already enhanced

                  let res;
                  try {
                    res = await fetch(this.audioUrl, {
                      signal: this.abortController.signal,
                      credentials: "omit",
                    });
                  } catch (e) {
                    // Likely CORS (common with S3-like storage). We keep placeholder waveform and default streaming.
                    console.warn("[CallAudioPlayer] Unable to fetch audio for waveform/seek enhancement:", e);
                    return;
                  }

                  if (!res || !res.ok) return;

                  const headerType = res.headers.get("content-type");
                  const mime = guessMimeType(this.audioUrl, headerType);

                  let arrayBuffer;
                  try {
                    arrayBuffer = await res.arrayBuffer();
                  } catch (_e) {
                    return;
                  }

                  if (this.abortController.signal.aborted) return;

                  // Swap audio to Blob URL (reliable seeking even without byte-range support)
                  const blob = new Blob([arrayBuffer], { type: mime });
                  const objectUrl = URL.createObjectURL(blob);

                  const keepTime = this.audioEl.currentTime || 0;
                  const wasPlaying = !this.audioEl.paused && !this.audioEl.ended;

                  // Pause and swap source; preserve time + play state
                  try {
                    this.audioEl.pause();
                  } catch (_e) {}

                  this.audioEl.src = objectUrl;
                  this.audioEl.load();

                  await waitForEvent(this.audioEl, "loadedmetadata", 2000);

                  try {
                    const duration = this.getDuration();
                    this.audioEl.currentTime = clamp(keepTime, 0, duration);
                  } catch (_e) {}

                  if (wasPlaying) {
                    try {
                      await this.audioEl.play();
                    } catch (_e) {}
                  }

                  this.objectUrl = objectUrl;
                  this.updateDurationUI();
                  this.updateTimeUI();

                  // Try to decode audio for a real waveform (best-effort)
                  try {
                    const AudioCtx = window.AudioContext || window.webkitAudioContext;
                    if (!AudioCtx) throw new Error("AudioContext not available");

                    const ctx = new AudioCtx();
                    const decoded = await ctx.decodeAudioData(arrayBuffer.slice(0));
                    try {
                      await ctx.close();
                    } catch (_e) {}

                    const peaks = computePeaksFromAudioBuffer(decoded, 1200);
                    if (peaks && peaks.length > 0) {
                      this.rawPeaks = peaks;
                      this.draw();
                    }
                  } catch (e) {
                    // Decoding might fail for some codecs/browsers; placeholder waveform is fine.
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

                  const barGap = 3; // px between bars (matches screenshot density)
                  const barCount = Math.max(1, Math.floor(width / barGap));
                  const peaks = resamplePeaksMax(this.rawPeaks, barCount);

                  const centerY = height / 2;
                  const maxBar = (height / 2) * 0.9;

                  const duration = this.getDuration();
                  const progress = duration > 0 ? clamp((this.audioEl.currentTime || 0) / duration, 0, 1) : 0;
                  const playedBars = Math.floor(progress * barCount);

                  ctx.lineCap = "round";
                  ctx.lineWidth = 1;

                  // Unplayed/base waveform
                  ctx.strokeStyle = this.baseColor;
                  ctx.beginPath();
                  for (let i = 0; i < barCount; i++) {
                    const x = i * barGap + barGap / 2;
                    const amp = Math.max(0.03, Math.pow(peaks[i] || 0, 0.75));
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
                      const amp = Math.max(0.03, Math.pow(peaks[i] || 0, 0.75));
                      const h = amp * maxBar;
                      ctx.moveTo(x, centerY - h);
                      ctx.lineTo(x, centerY + h);
                    }
                    ctx.stroke();
                  }
                },
              };
            </script>
          </section>

          <section class="space-y-4">
            <.tabs id="call-tabs">
              <.tabs_list
                active_tab={@active_tab}
                variant="ghost"
                size="sm"
                class="border-b border-base-300"
              >
                <:tab
                  name="overview"
                  id="tab-overview"
                  phx-click={JS.push("set_tab", value: %{tab: "overview"})}
                >
                  Overview
                </:tab>
                <:tab
                  name="transcription"
                  id="tab-transcription"
                  phx-click={JS.push("set_tab", value: %{tab: "transcription"})}
                >
                  Transcription
                </:tab>
                <:tab
                  name="client_data"
                  id="tab-client-data"
                  phx-click={JS.push("set_tab", value: %{tab: "client_data"})}
                >
                  Client data
                </:tab>
              </.tabs_list>

              <.tabs_panel
                name="overview"
                active={@active_tab == "overview"}
                id="overview-panel"
                class="pt-6 space-y-6"
              >
                <section class="rounded-3xl border border-base-300 bg-base-100 p-6 space-y-4">
                  <div class="flex items-center justify-between gap-3">
                    <h3 class="text-lg font-semibold text-foreground">Summary</h3>
                    <.badge variant="surface" color={@status_badge.color}>
                      {@status_badge.label}
                    </.badge>
                  </div>
                  <p class="text-base text-foreground-soft">{@summary_text}</p>
                  <div class="grid gap-4 sm:grid-cols-3">
                    <div class="rounded-2xl border border-base-200 bg-base-200/60 p-4">
                      <p class="text-xs uppercase tracking-wide text-foreground-softer">
                        Call status
                      </p>
                      <p class="mt-2 text-sm font-medium text-foreground">
                        {@metadata.status_label}
                      </p>
                    </div>
                    <div class="rounded-2xl border border-base-200 bg-base-200/60 p-4">
                      <p class="text-xs uppercase tracking-wide text-foreground-softer">
                        How the call ended
                      </p>
                      <p class="mt-2 text-sm font-medium text-foreground">
                        {@metadata.ended_reason}
                      </p>
                    </div>
                    <div class="rounded-2xl border border-base-200 bg-base-200/60 p-4">
                      <p class="text-xs uppercase tracking-wide text-foreground-softer">
                        User ID
                      </p>
                      <p class="mt-2 text-sm font-medium text-foreground">
                        {@metadata.user_id}
                      </p>
                    </div>
                  </div>
                </section>

                <section class="rounded-3xl border border-base-300 bg-base-100 p-6 space-y-4">
                  <div class="flex items-center justify-between gap-3">
                    <h3 class="text-lg font-semibold text-foreground">Artifacts</h3>
                    <span class="text-xs text-foreground-softer">
                      {Enum.count(artifact_links(@call))} items
                    </span>
                  </div>
                  <%= if artifact_links(@call) == [] do %>
                    <p class="text-sm text-foreground-soft">No artifacts available.</p>
                  <% else %>
                    <.table>
                      <.table_head>
                        <:col>Artifact</:col>
                        <:col class="text-right">Link</:col>
                      </.table_head>
                      <.table_body>
                        <.table_row :for={{label, url} <- artifact_links(@call)}>
                          <:cell>{label}</:cell>
                          <:cell class="text-right">
                            <.button
                              href={url}
                              target="_blank"
                              rel="noopener noreferrer"
                              variant="ghost"
                              size="xs"
                            >
                              Open
                            </.button>
                          </:cell>
                        </.table_row>
                      </.table_body>
                    </.table>
                  <% end %>
                </section>

                <section class="rounded-3xl border border-base-300 bg-base-100 p-6 space-y-4">
                  <div class="flex items-center justify-between gap-3">
                    <h3 class="text-lg font-semibold text-foreground">Recording tracks</h3>
                    <span class="text-xs text-foreground-softer">
                      {Enum.count(recording_links(@call))} tracks
                    </span>
                  </div>
                  <%= if recording_links(@call) == [] do %>
                    <p class="text-sm text-foreground-soft">No recordings available.</p>
                  <% else %>
                    <.table>
                      <.table_head>
                        <:col>Track</:col>
                        <:col>Preview</:col>
                        <:col class="text-right">Link</:col>
                      </.table_head>
                      <.table_body>
                        <.table_row :for={{label, url} <- recording_links(@call)}>
                          <:cell>{label}</:cell>
                          <:cell>
                            <audio controls src={url} class="w-full max-w-xs" preload="none"></audio>
                          </:cell>
                          <:cell class="text-right">
                            <.button
                              href={url}
                              target="_blank"
                              rel="noopener noreferrer"
                              variant="ghost"
                              size="xs"
                            >
                              Open
                            </.button>
                          </:cell>
                        </.table_row>
                      </.table_body>
                    </.table>
                  <% end %>
                </section>
              </.tabs_panel>

              <.tabs_panel
                name="transcription"
                active={@active_tab == "transcription"}
                id="transcription-panel"
                class="pt-6 space-y-6"
              >
                <div id="transcript-list" class="space-y-6">
                  <%= if @transcript_items == [] do %>
                    <p class="text-sm text-foreground-soft">No transcription events yet.</p>
                  <% else %>
                    <div :for={item <- @transcript_items} id={item_dom_id(item)}>
                      <%= if item.type == :message do %>
                        <div class={[
                          "flex gap-3",
                          item.role == :caller && "justify-end"
                        ]}>
                          <div class={[
                            "max-w-[75%] rounded-2xl px-4 py-3 shadow-sm",
                            item.role == :caller &&
                              "bg-base-100 border border-base-300 text-foreground",
                            item.role == :agent && "bg-base-200/80 text-foreground"
                          ]}>
                            <p class="text-sm leading-relaxed">{item.text}</p>
                            <div class="mt-2 flex items-center gap-2 text-[11px] text-foreground-softer">
                              <span class="uppercase tracking-wide">{item.label}</span>
                              <span>·</span>
                              <span>{item.offset}</span>
                            </div>
                          </div>
                        </div>
                      <% else %>
                        <div class="rounded-2xl border border-base-300 bg-base-100 p-4 shadow-sm space-y-3">
                          <div class="flex flex-wrap items-center justify-between gap-3">
                            <div class="flex items-center gap-2">
                              <.icon
                                name="hero-wrench-screwdriver"
                                class="size-4 text-foreground-softer"
                              />
                              <p class="text-sm font-semibold text-foreground">
                                Tool {item.status}: {item.name}
                              </p>
                            </div>
                            <div class="flex items-center gap-2 text-xs text-foreground-softer">
                              <span>{item.offset}</span>
                              <span>·</span>
                              <span>Result {item.duration_ms} ms</span>
                            </div>
                          </div>

                          <.accordion
                            id={"tool-accordion-#{item.id}"}
                            class="rounded-2xl border border-base-200"
                          >
                            <.accordion_item>
                              <:header class="flex items-center justify-between gap-3 text-sm font-medium text-foreground">
                                <span>Mcp call</span>
                                <.icon name="hero-chevron-down" class="icon text-foreground-softer" />
                              </:header>
                              <:panel>
                                <div class="space-y-4 text-xs text-foreground-soft">
                                  <div class="flex items-center justify-between">
                                    <span class="uppercase tracking-wide text-foreground-softer">
                                      MCP server information
                                    </span>
                                    <.badge size="xs" variant="surface">
                                      {item.mcp_server}
                                    </.badge>
                                  </div>

                                  <div class="rounded-xl border border-base-200 bg-base-200/60 p-3 space-y-2">
                                    <p class="text-xs uppercase tracking-wide text-foreground-softer">
                                      Parameters extracted by LLM
                                    </p>
                                    <pre
                                      phx-no-curly-interpolation
                                      class="text-[11px] whitespace-pre-wrap text-foreground"
                                    >{item.args}</pre>
                                  </div>

                                  <div class="rounded-xl border border-base-200 bg-base-200/60 p-3 space-y-2">
                                    <div class="flex items-center justify-between">
                                      <p class="text-xs uppercase tracking-wide text-foreground-softer">
                                        Response
                                      </p>
                                      <.button variant="ghost" size="icon-xs">
                                        <.icon name="hero-clipboard" class="icon" />
                                      </.button>
                                    </div>
                                    <pre
                                      phx-no-curly-interpolation
                                      class="text-[11px] whitespace-pre-wrap text-foreground"
                                    >{item.response}</pre>
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
              </.tabs_panel>

              <.tabs_panel
                name="client_data"
                active={@active_tab == "client_data"}
                id="client-data-panel"
                class="pt-6 space-y-6"
              >
                <section class="rounded-3xl border border-base-300 bg-base-100 p-6 space-y-4">
                  <h3 class="text-lg font-semibold text-foreground">Custom LLM extra body</h3>
                  <div class="rounded-2xl border border-base-200 bg-base-200/60 p-4">
                    <pre
                      phx-no-curly-interpolation
                      class="text-sm whitespace-pre-wrap text-foreground"
                    >{client_data_prompt(@client_data)}</pre>
                  </div>
                </section>

                <section class="rounded-3xl border border-base-300 bg-base-100 p-6 space-y-4">
                  <h3 class="text-lg font-semibold text-foreground">Configuration</h3>
                  <.list>
                    <:item title="Model">{@client_data.model || "—"}</:item>
                    <:item title="MCP endpoint">{@client_data.mcp_endpoint || "—"}</:item>
                    <:item title="Phone number">{@client_data.phone_number || "—"}</:item>
                    <:item title="Recording">{@client_data.recording || "—"}</:item>
                  </.list>
                </section>
              </.tabs_panel>
            </.tabs>
          </section>
        </div>

        <aside
          id="metadata-panel"
          class="rounded-3xl border border-base-300 bg-base-100 p-6 space-y-6"
        >
          <div class="flex items-start justify-between gap-3">
            <h3 class="text-lg font-semibold text-foreground">Metadata</h3>
            <.button size="icon-sm" variant="ghost">
              <.icon name="hero-x-mark" class="icon" />
            </.button>
          </div>
          <div class="space-y-4 text-sm">
            <div class="flex items-center justify-between border-b border-base-200 pb-3">
              <span class="text-foreground-soft">Date</span>
              <span class="font-medium text-foreground">{@metadata.date_label}</span>
            </div>
            <div class="flex items-center justify-between border-b border-base-200 pb-3">
              <span class="text-foreground-soft">Connection duration</span>
              <span class="font-medium text-foreground">{@metadata.duration_label}</span>
            </div>
            <div class="flex items-center justify-between border-b border-base-200 pb-3">
              <span class="text-foreground-soft">Call cost</span>
              <span class="font-medium text-foreground">{@metadata.call_cost}</span>
            </div>
            <div class="flex items-center justify-between border-b border-base-200 pb-3">
              <span class="text-foreground-soft">Credits (LLM)</span>
              <span class="font-medium text-foreground">{@metadata.credits}</span>
            </div>
            <div class="flex items-center justify-between">
              <span class="text-foreground-soft">LLM cost</span>
              <span class="font-medium text-foreground">{@metadata.llm_cost}</span>
            </div>
          </div>
        </aside>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    call = Calls.get_call!(socket.assigns.current_scope.tenant.id, id)

    {:ok, assign(socket, detail_assigns(call))}
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def detail_assigns(call) do
    events = call.events || []
    agent_label = agent_name(call)
    status_badge = status_badge(call.status)

    %{
      call: call,
      events: events,
      active_tab: "overview",
      primary_audio_url: primary_audio_url(call),
      agent_name: agent_label,
      status_badge: status_badge,
      summary_text: call.summary || "No summary has been generated yet.",
      metadata: build_metadata(call),
      client_data: extract_client_data(events),
      transcript_items: build_transcript_items(events, call.started_at, agent_label)
    }
  end

  defp primary_audio_url(call) do
    recording = call.recording || %{}
    map_value(recording, "stereo_url", :stereo_url)
  end

  defp recording_links(call) do
    recording = call.recording || %{}

    [
      {"Stereo mix", map_value(recording, "stereo_url", :stereo_url)},
      {"Caller track", map_value(recording, "caller_url", :caller_url)},
      {"Agent track", map_value(recording, "agent_url", :agent_url)}
    ]
    |> Enum.filter(&present_url?/1)
  end

  defp artifact_links(call) do
    transcript = call.transcript || %{}

    [
      {"Transcript text", map_value(transcript, "text_url", :text_url)},
      {"Transcript jsonl", map_value(transcript, "jsonl_url", :jsonl_url)}
    ]
    |> Enum.filter(&present_url?/1)
  end

  defp map_value(map, string_key, atom_key) when is_map(map) do
    Map.get(map, string_key) || Map.get(map, atom_key)
  end

  defp present_url?({_label, url}), do: url not in [nil, ""]

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

  defp build_metadata(call) do
    %{
      date_label: format_short_datetime(call.started_at),
      duration_label: format_duration(call.duration_seconds),
      call_cost: "—",
      credits: "—",
      llm_cost: "—",
      status_label: status_label(call.status),
      ended_reason: ended_reason(call.status),
      user_id: "No user ID"
    }
  end

  defp status_label(status) do
    case normalize_string(status) do
      "ended" -> "Successful"
      "cancelled" -> "Cancelled"
      "error" -> "Failed"
      "failed" -> "Failed"
      "started" -> "In progress"
      _ -> "Unknown"
    end
  end

  defp ended_reason(status) do
    case normalize_string(status) do
      "ended" -> "Client ended call"
      "cancelled" -> "Cancelled by system"
      "error" -> "Call failed"
      "failed" -> "Call failed"
      _ -> "—"
    end
  end

  defp format_long_datetime(nil), do: "—"

  defp format_long_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %-d, %Y • %I:%M %p")
  end

  defp format_short_datetime(nil), do: "—"

  defp format_short_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %-d, %I:%M %p")
  end

  defp format_duration(nil), do: "0:00"

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    remaining = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(remaining), 2, "0")}"
  end

  defp extract_client_data(events) do
    config_event = Enum.find(events, &(&1.type == "live_config_final"))
    payload = if config_event, do: config_event.payload || %{}, else: %{}
    mcp = map_value(payload, "mcp", :mcp) || %{}
    recording = map_value(payload, "recording", :recording) || %{}

    %{
      model: map_value(payload, "model", :model),
      mcp_endpoint: map_value(mcp, "endpoint", :endpoint),
      mcp_origin: map_value(mcp, "origin", :origin),
      phone_number: map_value(payload, "phone_number", :phone_number),
      system_prompt: map_value(payload, "system_prompt", :system_prompt),
      recording: recording_label(recording)
    }
  end

  defp recording_label(recording) when map_size(recording) == 0, do: "—"

  defp recording_label(recording) do
    enabled = map_value(recording, "enabled", :enabled)
    stereo = map_value(recording, "generate_stereo", :generate_stereo)
    agent = map_value(recording, "record_agent", :record_agent)
    caller = map_value(recording, "record_caller", :record_caller)

    label =
      [
        enabled && "enabled",
        stereo && "stereo",
        agent && "agent",
        caller && "caller"
      ]
      |> Enum.filter(& &1)
      |> Enum.join(", ")

    if label == "" do
      "—"
    else
      label
    end
  end

  defp client_data_prompt(%{system_prompt: prompt}) when is_binary(prompt), do: prompt
  defp client_data_prompt(_), do: "No system instructions captured."

  defp build_transcript_items(events, started_at, agent_label) do
    {items, current, tool_calls} =
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
                  {items, %{entry | text: append_text(entry.text, text)}, tool_calls}

                _ ->
                  {items, _current} = flush_current(items, current, started_at, agent_label)
                  {items, %{tag: tag, text: text, ts: event.ts}, tool_calls}
              end
            end

          "tool_call" ->
            payload = event.payload || %{}
            id = map_value(payload, "id", :id)

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
    args = map_value(call_payload, "args", :args) || %{}
    duration_ms = map_value(payload, "ms", :ms) || 0
    status = if map_value(payload, "isError", :isError), do: "failed", else: "succeeded"

    %{
      id: id || "tool-#{System.unique_integer([:positive])}",
      type: :tool,
      name: name,
      status: status,
      duration_ms: duration_ms,
      args: inspect(args, pretty: true, limit: 50),
      response: tool_response_text(payload),
      offset: format_offset(started_at, ts),
      mcp_server: "mcp_server"
    }
  end

  defp tool_response_text(payload) do
    response = map_value(payload, "response", :response) || %{}
    content = map_value(response, "content", :content) || []

    case List.first(content) do
      %{"text" => text} when is_binary(text) -> text
      %{text: text} when is_binary(text) -> text
      _ -> inspect(response, pretty: true, limit: 50)
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

    item = %{
      id: "msg-#{System.unique_integer([:positive])}",
      type: :message,
      role: role,
      label: if(role == :caller, do: "Caller", else: agent_label),
      text: String.trim(current.text),
      offset: format_offset(started_at, current.ts)
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

  defp format_offset(nil, _ts), do: "0:00"

  defp format_offset(%DateTime{} = start, %DateTime{} = ts) do
    seconds = max(DateTime.diff(ts, start, :second), 0)
    format_duration(seconds)
  end

  defp normalize_string(nil), do: ""
  defp normalize_string(value) when is_binary(value), do: String.downcase(value)
  defp normalize_string(value), do: value |> to_string() |> String.downcase()

  defp item_dom_id(%{type: :message, dom_index: index}), do: "transcript-item-#{index}"
  defp item_dom_id(%{type: :tool, dom_index: index}), do: "tool-item-#{index}"
end
