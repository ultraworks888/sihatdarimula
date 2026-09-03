import {
  ResponsiveContainer, XAxis, YAxis,
  CartesianGrid, Tooltip, Area, AreaChart, Line,
} from "recharts";
import { useLang } from "../contexts/LanguageContext";

interface GrowthLog {
  id: string;
  date: string;
  weight_kg: number;
  height_cm: number;
  head_cm: number;
}

interface Props {
  logs: GrowthLog[];
  childDob?: string;
}

type Metric = "weight" | "height" | "head";

// WHO medians (boys — approximate reference only)
const WHO_WEIGHT_KG: Record<number, number> = {
  0: 3.3, 1: 4.5, 2: 5.6, 3: 6.4, 4: 7.0, 5: 7.5, 6: 7.9,
  7: 8.3, 8: 8.6, 9: 9.0, 10: 9.2, 11: 9.4, 12: 9.6,
  15: 10.3, 18: 10.9, 21: 11.5, 24: 12.2, 30: 13.3,
  36: 14.3, 42: 15.3, 48: 16.3,
};
const WHO_HEIGHT_CM: Record<number, number> = {
  0: 49.9, 1: 54.7, 2: 58.4, 3: 61.4, 4: 63.9, 5: 65.9, 6: 67.6,
  7: 69.2, 8: 70.6, 9: 72.0, 10: 73.3, 11: 74.5, 12: 75.7,
  15: 79.1, 18: 82.3, 21: 85.1, 24: 87.8, 30: 92.7,
  36: 96.1, 42: 99.9, 48: 103.3,
};

function getAgeMonths(dob: string, dateStr: string): number {
  const birth = new Date(dob);
  const d = new Date(dateStr);
  return Math.round((d.getFullYear() - birth.getFullYear()) * 12 + (d.getMonth() - birth.getMonth()));
}

function formatDate(dateStr: string): string {
  const d = new Date(dateStr);
  return d.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

function whoRef(table: Record<number, number>, ageMonths: number): number | null {
  const keys = Object.keys(table).map(Number).sort((a, b) => a - b);
  const lo = keys.filter(k => k <= ageMonths).pop();
  const hi = keys.find(k => k > ageMonths);
  if (lo === undefined) return null;
  if (hi === undefined) return table[lo];
  const frac = (ageMonths - lo) / (hi - lo);
  return table[lo] + frac * (table[hi] - table[lo]);
}

const CustomTooltip = ({ active, payload, label, metric }: {
  active?: boolean; payload?: { value: number; name: string }[]; label?: string; metric: Metric;
}) => {
  if (!active || !payload?.length) return null;
  const unit = metric === "weight" ? "kg" : "cm";
  const recorded = payload.find(p => p.name === "recorded");
  const reference = payload.find(p => p.name === "who");
  return (
    <div className="glass-strong rounded-2xl px-3 py-2 text-xs shadow-xl">
      <p className="font-bold text-gray-700 mb-1">{label}</p>
      {recorded && (
        <p className="text-violet-600 font-semibold">{recorded.value.toFixed(1)} {unit}</p>
      )}
      {reference && reference.value > 0 && (
        <p className="text-gray-400">WHO ref: {reference.value.toFixed(1)} {unit}</p>
      )}
    </div>
  );
};

export default function GrowthChart({ logs, childDob }: Props) {
  const { t } = useLang();
  const sortedLogs = [...logs].filter(l => l.date).sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());

  const metrics: { key: Metric; label: string; color: string; gradId: string; unit: string }[] = [
    { key: "weight", label: t("weightKg"), color: "#8b5cf6", gradId: "gradWeight", unit: "kg" },
    { key: "height", label: t("heightCm"), color: "#3b82f6", gradId: "gradHeight", unit: "cm" },
    { key: "head",   label: t("headCm"),   color: "#10b981", gradId: "gradHead",   unit: "cm" },
  ];

  // Build chart data with optional WHO reference
  const buildData = (metric: Metric) => {
    return sortedLogs
      .filter(l => {
        if (metric === "weight") return l.weight_kg > 0;
        if (metric === "height") return l.height_cm > 0;
        return l.head_cm > 0;
      })
      .map(l => {
        const value = metric === "weight" ? l.weight_kg : metric === "height" ? l.height_cm : l.head_cm;
        let who: number | null = null;
        if (childDob) {
          const ageMo = getAgeMonths(childDob, l.date);
          if (metric === "weight") who = whoRef(WHO_WEIGHT_KG, ageMo);
          else if (metric === "height") who = whoRef(WHO_HEIGHT_CM, ageMo);
        }
        return {
          date: formatDate(l.date),
          recorded: parseFloat(value.toFixed(2)),
          who: who !== null ? parseFloat(who.toFixed(2)) : null,
        };
      });
  };

  // Latest values & trend
  const latest = (metric: Metric) => {
    const vals = sortedLogs.filter(l => {
      if (metric === "weight") return l.weight_kg > 0;
      if (metric === "height") return l.height_cm > 0;
      return l.head_cm > 0;
    });
    if (!vals.length) return null;
    return metric === "weight" ? vals[vals.length - 1].weight_kg
      : metric === "height" ? vals[vals.length - 1].height_cm
      : vals[vals.length - 1].head_cm;
  };

  const trend = (metric: Metric) => {
    const vals = sortedLogs.filter(l => {
      if (metric === "weight") return l.weight_kg > 0;
      if (metric === "height") return l.height_cm > 0;
      return l.head_cm > 0;
    });
    if (vals.length < 2) return null;
    const prev = metric === "weight" ? vals[vals.length - 2].weight_kg
      : metric === "height" ? vals[vals.length - 2].height_cm
      : vals[vals.length - 2].head_cm;
    const curr = metric === "weight" ? vals[vals.length - 1].weight_kg
      : metric === "height" ? vals[vals.length - 1].height_cm
      : vals[vals.length - 1].head_cm;
    return parseFloat((curr - prev).toFixed(2));
  };

  if (sortedLogs.length === 0) {
    return (
      <div className="glass rounded-3xl p-8 text-center">
        <span className="text-4xl">📈</span>
        <p className="text-gray-500 text-sm mt-3 font-medium">{t("noChartData")}</p>
        <p className="text-gray-400 text-xs mt-1">{t("noChartDataDesc")}</p>
      </div>
    );
  }

  return (
    <div className="glass-strong rounded-3xl p-4 space-y-5">
      {/* Header */}
      <div>
        <h3 className="font-bold text-gray-800 flex items-center gap-2">
          📈 {t("growthChart")}
        </h3>
        {childDob && <p className="text-xs text-gray-400 mt-0.5">{t("whoRefNote")}</p>}
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-3 gap-2">
        {metrics.map(m => {
          const val = latest(m.key);
          const diff = trend(m.key);
          if (val === null) return null;
          return (
            <div key={m.key} className="glass rounded-2xl p-3 text-center">
              <p className="text-[10px] text-gray-400 font-semibold uppercase tracking-wide">{m.label}</p>
              <p className="text-lg font-bold mt-0.5" style={{ color: m.color }}>
                {val.toFixed(1)}<span className="text-xs font-normal"> {m.unit}</span>
              </p>
              {diff !== null && (
                <p className={`text-[10px] font-semibold mt-0.5 ${diff >= 0 ? "text-emerald-500" : "text-rose-500"}`}>
                  {diff >= 0 ? "▲" : "▼"} {Math.abs(diff).toFixed(2)} {m.unit}
                </p>
              )}
            </div>
          );
        })}
      </div>

      {/* Individual Charts */}
      {metrics.map(m => {
        const data = buildData(m.key);
        if (data.length === 0) return null;
        const hasWho = data.some(d => d.who !== null);
        const allVals = data.flatMap(d => [d.recorded, d.who ?? 0]).filter(v => v > 0);
        const minVal = Math.floor(Math.min(...allVals) * 0.95);
        const maxVal = Math.ceil(Math.max(...allVals) * 1.05);

        return (
          <div key={m.key}>
            <div className="flex items-center justify-between mb-2">
              <h4 className="text-sm font-bold" style={{ color: m.color }}>{m.label}</h4>
              {hasWho && (
                <div className="flex items-center gap-3 text-[10px] text-gray-400">
                  <span className="flex items-center gap-1"><span className="w-3 h-0.5 rounded-full" style={{ background: m.color, display: "inline-block" }} /> {t("recorded")}</span>
                  <span className="flex items-center gap-1"><span className="w-3 border-t border-dashed border-gray-400 inline-block" /> {t("whoMedian")}</span>
                </div>
              )}
            </div>
            <ResponsiveContainer width="100%" height={160}>
              <AreaChart data={data} margin={{ top: 4, right: 4, left: -20, bottom: 0 }}>
                <defs>
                  <linearGradient id={m.gradId} x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor={m.color} stopOpacity={0.25} />
                    <stop offset="100%" stopColor={m.color} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.05)" vertical={false} />
                <XAxis dataKey="date" tick={{ fontSize: 10, fill: "#9ca3af" }} axisLine={false} tickLine={false} />
                <YAxis domain={[minVal, maxVal]} tick={{ fontSize: 10, fill: "#9ca3af" }} axisLine={false} tickLine={false} width={40} />
                <Tooltip content={<CustomTooltip metric={m.key} />} />
                {hasWho && (
                  <Line
                    type="monotone" dataKey="who" name="who"
                    stroke="rgba(156,163,175,0.6)" strokeWidth={1.5}
                    strokeDasharray="4 3" dot={false} connectNulls
                  />
                )}
                <Area
                  type="monotone" dataKey="recorded" name="recorded"
                  stroke={m.color} strokeWidth={2.5}
                  fill={`url(#${m.gradId})`}
                  dot={{ fill: m.color, strokeWidth: 0, r: 4 }}
                  activeDot={{ r: 6, fill: m.color, stroke: "white", strokeWidth: 2 }}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        );
      })}
    </div>
  );
}
