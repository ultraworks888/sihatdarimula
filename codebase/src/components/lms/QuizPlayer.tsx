import { useState } from "react";
import { Trophy, RotateCcw, ChevronRight } from "lucide-react";

export interface QuizQuestion {
  question: string;
  options: string[];
  correct: number;
  explanation?: string;
}

interface Props {
  questions: QuizQuestion[];
  passingScore?: number;
  onPass: (score: number) => void;
  onFail: (score: number) => void;
}

export default function QuizPlayer({ questions, passingScore = 70, onPass, onFail }: Props) {
  const [current, setCurrent] = useState(0);
  const [selected, setSelected] = useState<number | null>(null);
  const [answers, setAnswers] = useState<number[]>([]);
  const [showResult, setShowResult] = useState(false);
  const [showExplanation, setShowExplanation] = useState(false);

  const q = questions[current];
  const totalQ = questions.length;
  const isLast = current === totalQ - 1;

  const handleNext = () => {
    if (selected === null) return;
    const newAnswers = [...answers, selected];
    setAnswers(newAnswers);
    if (isLast) {
      const correct = newAnswers.filter((a, i) => a === questions[i].correct).length;
      const score = Math.round((correct / totalQ) * 100);
      setShowResult(true);
      if (score >= passingScore) onPass(score); else onFail(score);
    } else {
      setCurrent(c => c + 1);
      setSelected(null);
      setShowExplanation(false);
    }
  };

  const handleRetry = () => {
    setCurrent(0); setSelected(null); setAnswers([]); setShowResult(false); setShowExplanation(false);
  };

  if (showResult) {
    const correct = answers.filter((a, i) => a === questions[i].correct).length;
    const score = Math.round((correct / totalQ) * 100);
    const passed = score >= passingScore;
    return (
      <div className="p-6 text-center space-y-4">
        <div className={`w-20 h-20 mx-auto rounded-full flex items-center justify-center ${passed ? "bg-emerald-100" : "bg-rose-100"}`}>
          <Trophy size={36} className={passed ? "text-emerald-600" : "text-rose-500"} />
        </div>
        <div>
          <p className={`text-2xl font-bold ${passed ? "text-emerald-600" : "text-rose-500"}`}>
            {passed ? "Well done!" : "Not quite yet"}
          </p>
          <p className="text-gray-600 mt-1">Your score: <span className="font-bold">{score}%</span> · Pass mark: {passingScore}%</p>
          <p className="text-gray-500 text-sm mt-1">{correct} of {totalQ} correct</p>
        </div>
        {!passed && (
          <button onClick={handleRetry}
            className="flex items-center gap-2 mx-auto px-6 py-3 rounded-2xl bg-amber-500 text-white font-semibold text-sm">
            <RotateCcw size={16} /> Try Again
          </button>
        )}
      </div>
    );
  }

  return (
    <div className="p-5 space-y-5">
      <div className="flex items-center justify-between">
        <p className="text-xs text-gray-400 font-semibold">Question {current + 1} of {totalQ}</p>
        <div className="flex gap-1">
          {questions.map((_, i) => (
            <div key={i} className={`h-1.5 rounded-full transition-all ${i < current ? "w-4 bg-amber-400" : i === current ? "w-6 bg-amber-500" : "w-4 bg-gray-200"}`} />
          ))}
        </div>
      </div>
      <p className="font-semibold text-gray-800 text-[15px] leading-relaxed">{q.question}</p>
      <div className="space-y-2.5">
        {q.options.map((opt, i) => (
          <button key={i} onClick={() => { setSelected(i); setShowExplanation(false); }}
            className={`w-full text-left px-4 py-3 rounded-2xl border-2 text-sm font-medium transition-all ${
              selected === i
                ? "border-amber-400 bg-amber-50 text-amber-800"
                : "border-gray-100 bg-white text-gray-700 hover:border-amber-200"
            }`}>
            <span className="font-bold mr-2 text-gray-400">{String.fromCharCode(65 + i)}.</span>{opt}
          </button>
        ))}
      </div>
      {q.explanation && selected !== null && (
        <button onClick={() => setShowExplanation(v => !v)}
          className="text-xs text-amber-600 underline underline-offset-2">
          {showExplanation ? "Hide" : "Show"} hint
        </button>
      )}
      {showExplanation && q.explanation && (
        <p className="text-xs text-gray-500 bg-amber-50 rounded-xl px-3 py-2 leading-relaxed">{q.explanation}</p>
      )}
      <button onClick={handleNext} disabled={selected === null}
        className={`w-full py-3 rounded-2xl font-semibold text-sm flex items-center justify-center gap-2 transition-all ${
          selected !== null ? "bg-amber-500 text-white" : "bg-gray-100 text-gray-400 cursor-not-allowed"
        }`}>
        {isLast ? "Submit Quiz" : "Next"} <ChevronRight size={16} />
      </button>
    </div>
  );
}
