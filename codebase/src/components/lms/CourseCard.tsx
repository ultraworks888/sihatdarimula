import { BookOpen, Clock, ChevronRight } from "lucide-react";
import pb from "../../lib/pocketbase";

const levelColors: Record<string, string> = {
  beginner: "text-emerald-600 bg-emerald-50",
  intermediate: "text-amber-600 bg-amber-50",
  advanced: "text-rose-600 bg-rose-50",
};

const categoryColors: Record<string, string> = {
  parenting: "text-violet-600 bg-violet-50",
  nutrition: "text-orange-600 bg-orange-50",
  development: "text-blue-600 bg-blue-50",
  wellbeing: "text-teal-600 bg-teal-50",
  breastfeeding: "text-pink-600 bg-pink-50",
  pregnancy: "text-rose-600 bg-rose-50",
};

interface Props {
  course: Record<string, unknown>;
  progress?: number;
  lessonCount?: number;
  lang?: string;
  onClick: () => void;
}

export default function CourseCard({ course, progress = 0, lessonCount = 0, lang = "en", onClick }: Props) {
  const getField = (field: string) => {
    if (lang !== "en") {
      const loc = course[`${field}_${lang}`];
      if (loc && String(loc).trim()) return String(loc);
    }
    return String(course[`${field}_en`] ?? course[field] ?? "");
  };

  const thumbnail = course.thumbnail
    ? pb.files.getURL(course as never, String(course.thumbnail), { thumb: "400x225" })
    : null;

  const cat = String(course.category ?? "parenting");
  const level = String(course.level ?? "beginner");
  const catColor = categoryColors[cat] ?? categoryColors.parenting;
  const lvlColor = levelColors[level] ?? levelColors.beginner;

  return (
    <button onClick={onClick}
      className="glass rounded-3xl overflow-hidden w-full text-left group active:scale-[0.99] transition-all duration-200">
      {thumbnail ? (
        <img src={thumbnail} alt={getField("title")} className="w-full h-40 object-cover" />
      ) : (
        <img
          src="https://images.unsplash.com/photo-1519689680058-324335c77eba?w=800&auto=format&fit=crop&q=80"
          alt="Mother with newborn"
          className="w-full h-40 object-cover"
        />
      )}
      <div className="p-4">
        <div className="flex items-center gap-1.5 mb-2 flex-wrap">
          <span className={`text-[10px] font-bold uppercase px-2 py-0.5 rounded-full ${catColor}`}>{cat}</span>
          <span className={`text-[10px] font-bold uppercase px-2 py-0.5 rounded-full ${lvlColor}`}>{level}</span>
          {course.is_featured && (
            <span className="text-[10px] font-bold uppercase px-2 py-0.5 rounded-full text-amber-700 bg-amber-100">Featured</span>
          )}
        </div>
        <h3 className="font-bold text-gray-800 text-[15px] leading-snug group-hover:text-amber-700 transition-colors line-clamp-2">
          {getField("title")}
        </h3>
        <p className="text-gray-500 text-[13px] mt-1 line-clamp-2 leading-relaxed">{getField("description")}</p>
        <div className="flex items-center justify-between mt-3 pt-3 border-t border-white/40">
          <div className="flex items-center gap-3 text-xs text-gray-400">
            <span className="flex items-center gap-1"><BookOpen size={11} />{lessonCount} lessons</span>
            {progress > 0 && <span className="flex items-center gap-1"><Clock size={11} />{progress}% done</span>}
          </div>
          <ChevronRight size={16} className="text-amber-500" />
        </div>
        {progress > 0 && (
          <div className="mt-2 h-1.5 rounded-full bg-gray-100 overflow-hidden">
            <div className="h-full rounded-full bg-gradient-to-r from-amber-400 to-emerald-400 transition-all duration-500"
              style={{ width: `${Math.min(progress, 100)}%` }} />
          </div>
        )}
      </div>
    </button>
  );
}
