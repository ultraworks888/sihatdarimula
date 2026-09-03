import { useRef, useState, useCallback, useEffect } from "react";
import ReactPlayer from "react-player";
import { CheckCircle, PlayCircle } from "lucide-react";

interface Props {
  videoUrl: string;
  provider?: string;
  threshold?: number;
  startPosition?: number;
  onProgress?: (percent: number, seconds: number) => void;
  onComplete?: () => void;
}

// ─── Bunny Stream Player ──────────────────────────────────────────────────────
// Uses Bunny's postMessage API for automatic progress tracking.
// Falls back to a "Mark as Watched" button if postMessage events don't arrive.

function BunnyPlayer({ videoUrl, threshold = 100, onProgress, onComplete }: Omit<Props, "provider">) {
  const [completed, setCompleted]   = useState(false);
  const [manualDone, setManualDone] = useState(false);
  const completedRef = useRef(false);

  // Reset on video change
  useEffect(() => {
    completedRef.current = false;
    setCompleted(false);
    setManualDone(false);
  }, [videoUrl]);

  // Listen for Bunny Stream postMessage events
  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      if (!event.data || typeof event.data !== "object") return;
      const d = event.data as Record<string, unknown>;

      // Bunny player sends { event: "timeupdate", currentTime: N, duration: N }
      // Also handle alternate { type: "..." } format defensively
      const evtName    = String(d.event ?? d.type ?? "");
      const currentTime = Number(d.currentTime ?? d.current_time ?? 0);
      const duration    = Number(d.duration ?? d.totalTime ?? 0);

      if ((evtName === "timeupdate" || evtName === "progress") && duration > 0) {
        const pct = Math.round((currentTime / duration) * 100);
        onProgress?.(pct, currentTime);
        if (pct >= threshold && !completedRef.current) {
          completedRef.current = true;
          setCompleted(true);
          onComplete?.();
        }
      }

      if (evtName === "ended" && !completedRef.current) {
        completedRef.current = true;
        setCompleted(true);
        onComplete?.();
      }
    };

    window.addEventListener("message", handleMessage);
    return () => window.removeEventListener("message", handleMessage);
  }, [threshold, onProgress, onComplete]);

  const markWatched = () => {
    if (completedRef.current) return;
    completedRef.current = true;
    setManualDone(true);
    setCompleted(true);
    onComplete?.();
  };

  return (
    <div className="w-full bg-black">
      <div className="aspect-video">
        <iframe
          src={videoUrl}
          className="w-full h-full"
          allow="autoplay; fullscreen; encrypted-media"
          allowFullScreen
        />
      </div>
      {completed || manualDone ? (
        <div className="w-full py-3 bg-emerald-600 text-white font-semibold text-sm flex items-center justify-center gap-2">
          <CheckCircle size={16} /> Watched
        </div>
      ) : (
        <button
          onClick={markWatched}
          className="w-full py-3 bg-amber-500 text-white font-semibold text-sm flex items-center justify-center gap-2"
        >
          <CheckCircle size={16} /> Mark as Watched
        </button>
      )}
    </div>
  );
}

// ─── Cloudflare Stream Player ─────────────────────────────────────────────────
// Simple iframe with manual completion button.

function CloudflarePlayer({ videoUrl, onComplete }: Pick<Props, "videoUrl" | "onComplete">) {
  const [done, setDone] = useState(false);

  useEffect(() => { setDone(false); }, [videoUrl]);

  return (
    <div className="w-full bg-black">
      <div className="aspect-video">
        <iframe
          src={videoUrl}
          className="w-full h-full"
          allow="autoplay; fullscreen; encrypted-media"
          allowFullScreen
        />
      </div>
      {done ? (
        <div className="w-full py-3 bg-emerald-600 text-white font-semibold text-sm flex items-center justify-center gap-2">
          <CheckCircle size={16} /> Watched
        </div>
      ) : (
        <button
          onClick={() => { setDone(true); onComplete?.(); }}
          className="w-full py-3 bg-amber-500 text-white font-semibold text-sm flex items-center justify-center gap-2"
        >
          <CheckCircle size={16} /> Mark as Watched
        </button>
      )}
    </div>
  );
}

// ─── Main VideoPlayer ─────────────────────────────────────────────────────────

export default function VideoPlayer({
  videoUrl,
  provider,
  threshold = 100,
  startPosition = 0,
  onProgress,
  onComplete,
}: Props) {
  const playerRef    = useRef<ReactPlayer>(null);
  const [started, setStarted]             = useState(false);
  const [videoCompleted, setVideoCompleted] = useState(false);
  const completedRef   = useRef(false);
  const startSeekDone  = useRef(false);

  const isBunny      = provider === "bunny"             || videoUrl.includes("mediadelivery.net");
  const isCloudflare = provider === "cloudflare_stream" || videoUrl.includes("cloudflarestream.com");

  // Reset on video URL change
  useEffect(() => {
    completedRef.current = false;
    setVideoCompleted(false);
    startSeekDone.current = false;
    setStarted(false);
  }, [videoUrl]);

  const handleReady = useCallback(() => {
    if (!startSeekDone.current && startPosition > 0 && playerRef.current) {
      playerRef.current.seekTo(startPosition, "seconds");
      startSeekDone.current = true;
    }
  }, [startPosition]);

  const handleProgress = useCallback(
    ({ played, playedSeconds }: { played: number; playedSeconds: number }) => {
      const pct = Math.round(played * 100);
      onProgress?.(pct, playedSeconds);
      if (pct >= threshold && !completedRef.current) {
        completedRef.current = true;
        setVideoCompleted(true);
        onComplete?.();
      }
    },
    [threshold, onProgress, onComplete],
  );

  const handleEnded = useCallback(() => {
    if (!completedRef.current) {
      completedRef.current = true;
      setVideoCompleted(true);
      onComplete?.();
    }
  }, [onComplete]);

  // ── Bunny Stream ──
  if (isBunny) {
    return (
      <BunnyPlayer
        videoUrl={videoUrl}
        threshold={threshold}
        onProgress={onProgress}
        onComplete={onComplete}
      />
    );
  }

  // ── Cloudflare Stream ──
  if (isCloudflare) {
    return <CloudflarePlayer videoUrl={videoUrl} onComplete={onComplete} />;
  }

  // ── YouTube / Direct MP4 (ReactPlayer) ──
  return (
    <div className="w-full bg-black relative">
      <div className="aspect-video">
        {!started && (
          <button
            onClick={() => setStarted(true)}
            className="absolute inset-0 flex items-center justify-center bg-black/60 z-10 group"
          >
            <div className="w-16 h-16 rounded-full bg-amber-500 flex items-center justify-center group-hover:scale-110 transition-transform shadow-2xl">
              <PlayCircle size={36} className="text-white" />
            </div>
          </button>
        )}
        <ReactPlayer
          ref={playerRef}
          url={videoUrl}
          playing={started}
          controls
          width="100%"
          height="100%"
          onReady={handleReady}
          onStart={() => setStarted(true)}
          onProgress={handleProgress}
          onEnded={handleEnded}
          progressInterval={3000}
          config={{ youtube: { playerVars: { rel: 0, modestbranding: 1 } } }}
        />
      </div>
      {videoCompleted && (
        <div className="absolute top-2 right-2 bg-emerald-500 text-white text-xs font-bold px-2 py-1 rounded-full flex items-center gap-1 z-20">
          <CheckCircle size={12} /> Done
        </div>
      )}
    </div>
  );
}
