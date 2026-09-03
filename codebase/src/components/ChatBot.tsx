import { useState, useRef, useEffect } from "react";
import { X, Send, Sparkles, Bot } from "lucide-react";
import pb from "../lib/pocketbase";
import { useLang } from "../contexts/LanguageContext";

interface Message {
  role: "user" | "assistant";
  content: string;
}

const STARTERS: Record<string, string[]> = {
  en: [
    "When should my baby start solid foods?",
    "How do I know if my baby is getting enough milk?",
    "What are signs of postpartum depression?",
    "How often should a newborn feed?",
  ],
  ms: [
    "Bilakah bayi saya boleh mula makan makanan pejal?",
    "Bagaimana tahu bayi mendapat susu yang cukup?",
    "Apakah tanda-tanda kemurungan selepas bersalin?",
    "Berapa kerapkah bayi baru lahir perlu disusukan?",
  ],
  zh: [
    "宝宝什么时候可以开始吃固体食物？",
    "如何知道宝宝是否获得足够的母乳？",
    "产后抑郁症有哪些迹象？",
    "新生儿多久喂一次奶？",
  ],
};

const UI: Record<string, Record<string, string>> = {
  en: {
    title:       "Parenting Assistant",
    subtitle:    "Ask me anything about parenting",
    placeholder: "Type your question...",
    disclaimer:  "For medical emergencies, always consult your doctor.",
  },
  ms: {
    title:       "Pembantu Keibubapaan",
    subtitle:    "Tanya saya tentang keibubapaan",
    placeholder: "Taip soalan anda...",
    disclaimer:  "Untuk kecemasan perubatan, sila hubungi doktor anda.",
  },
  zh: {
    title:       "育儿助手",
    subtitle:    "向我询问任何育儿问题",
    placeholder: "输入您的问题...",
    disclaimer:  "如有医疗紧急情况，请立即咨询医生。",
  },
};

const GRADIENT = "linear-gradient(135deg, #7c3aed, #ec4899)";

export default function ChatBot() {
  const { lang } = useLang();
  const [open, setOpen]       = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput]     = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError]     = useState("");

  const bottomRef  = useRef<HTMLDivElement>(null);
  const inputRef   = useRef<HTMLTextAreaElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const ui       = UI[lang]       || UI.en;
  const starters = STARTERS[lang] || STARTERS.en;

  useEffect(() => {
    if (open) setTimeout(() => inputRef.current?.focus(), 300);
  }, [open]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, loading]);

  const autoResize = () => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = Math.min(el.scrollHeight, 100) + "px";
  };

  const send = async (text: string) => {
    const trimmed = text.trim();
    if (!trimmed || loading) return;

    setInput("");
    if (textareaRef.current) textareaRef.current.style.height = "auto";
    setError("");

    const userMsg: Message = { role: "user", content: trimmed };
    setMessages(prev => [...prev, userMsg]);
    setLoading(true);

    try {
      const history = messages.slice(-6).map(m => ({ role: m.role, content: m.content }));
      const res = await fetch(`${import.meta.env.VITE_POCKETBASE_URL}/api/chat/ask`, {
        method:  "POST",
        headers: {
          "Content-Type":  "application/json",
          "Authorization": `Bearer ${pb.authStore.token}`,
        },
        body: JSON.stringify({ message: trimmed, history }),
      });
      const data = await res.json();
      if (res.ok && data.answer) {
        setMessages(prev => [...prev, { role: "assistant", content: data.answer }]);
      } else {
        setError(data.message || data.error || `Error ${res.status}. Please try again.`);
      }
    } catch {
      setError("Unable to reach the assistant. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const handleKey = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(input); }
  };

  return (
    <>
      {/* Floating button — shown when chat is closed */}
      {!open && (
        <button
          onClick={() => setOpen(true)}
          className="absolute bottom-[116px] right-4 z-40 flex items-center gap-1.5 pl-3 pr-4 py-2.5 rounded-full text-white text-xs font-bold shadow-lg transition-all hover:scale-105 active:scale-95"
          style={{ background: GRADIENT, boxShadow: "0 4px 20px rgba(124,58,237,0.35)" }}
          aria-label="Open AI chat assistant"
        >
          <Sparkles size={14} />
          AI Chat
        </button>
      )}

      {/* Chat panel — full overlay within layout container */}
      {open && (
        <div className="absolute inset-0 z-50 flex flex-col" style={{ background: "#fdf8f4" }}>

          {/* Header */}
          <div
            className="shrink-0 flex items-center gap-3 px-4 py-3 text-white"
            style={{ background: GRADIENT }}
          >
            <div className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center shrink-0">
              <Bot size={17} className="text-white" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="font-bold text-sm leading-tight">{ui.title}</p>
              <p className="text-white/70 text-[11px]">{ui.subtitle}</p>
            </div>
            <button
              onClick={() => setOpen(false)}
              className="w-8 h-8 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center transition-colors"
              aria-label="Close"
            >
              <X size={16} />
            </button>
          </div>

          {/* Messages */}
          <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3">
            {messages.length === 0 ? (
              /* Empty state with starter prompts */
              <div className="space-y-5 pt-2">
                <div className="text-center">
                  <div
                    className="w-14 h-14 rounded-full mx-auto mb-3 flex items-center justify-center"
                    style={{ background: "linear-gradient(135deg,#7c3aed18,#ec489918)" }}
                  >
                    <Sparkles size={24} className="text-violet-500" />
                  </div>
                  <p className="text-gray-500 text-xs leading-relaxed max-w-[220px] mx-auto">
                    {ui.disclaimer}
                  </p>
                </div>
                <div className="space-y-2">
                  {starters.map((s, i) => (
                    <button
                      key={i}
                      onClick={() => send(s)}
                      className="w-full text-left text-sm px-4 py-3 bg-white rounded-2xl border border-violet-100 text-gray-700 hover:border-violet-300 hover:bg-violet-50/50 transition-all shadow-sm"
                    >
                      {s}
                    </button>
                  ))}
                </div>
              </div>
            ) : (
              <>
                {messages.map((msg, i) => (
                  <div
                    key={i}
                    className={`flex gap-2 ${msg.role === "user" ? "justify-end" : "justify-start"}`}
                  >
                    {msg.role === "assistant" && (
                      <div
                        className="w-7 h-7 rounded-full shrink-0 mt-0.5 flex items-center justify-center"
                        style={{ background: GRADIENT }}
                      >
                        <Bot size={13} className="text-white" />
                      </div>
                    )}
                    <div
                      className={`max-w-[82%] px-4 py-2.5 rounded-2xl text-sm leading-relaxed whitespace-pre-wrap ${
                        msg.role === "user"
                          ? "text-white rounded-tr-sm"
                          : "bg-white text-gray-800 rounded-tl-sm shadow-sm border border-gray-100"
                      }`}
                      style={msg.role === "user" ? { background: GRADIENT } : {}}
                    >
                      {msg.content}
                    </div>
                  </div>
                ))}

                {/* Typing indicator */}
                {loading && (
                  <div className="flex justify-start gap-2">
                    <div
                      className="w-7 h-7 rounded-full shrink-0 flex items-center justify-center"
                      style={{ background: GRADIENT }}
                    >
                      <Bot size={13} className="text-white" />
                    </div>
                    <div className="bg-white border border-gray-100 shadow-sm px-4 py-3 rounded-2xl rounded-tl-sm flex gap-1 items-center">
                      {[0, 150, 300].map(delay => (
                        <span
                          key={delay}
                          className="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce"
                          style={{ animationDelay: `${delay}ms` }}
                        />
                      ))}
                    </div>
                  </div>
                )}

                {error && (
                  <p className="text-rose-500 text-xs text-center px-4">{error}</p>
                )}
              </>
            )}
            <div ref={bottomRef} />
          </div>

          {/* Input area */}
          <div className="shrink-0 px-4 py-3 bg-white border-t border-gray-100">
            <div className="flex items-end gap-2">
              <textarea
                ref={(el) => {
                  (inputRef as React.MutableRefObject<HTMLTextAreaElement | null>).current = el;
                  (textareaRef as React.MutableRefObject<HTMLTextAreaElement | null>).current = el;
                }}
                rows={1}
                value={input}
                onChange={e => { setInput(e.target.value); autoResize(); }}
                onKeyDown={handleKey}
                placeholder={ui.placeholder}
                className="flex-1 resize-none bg-gray-50 border border-gray-200 rounded-2xl px-4 py-2.5 text-sm text-gray-800 outline-none focus:border-violet-300 transition-colors placeholder-gray-400 overflow-y-auto"
                style={{ maxHeight: 100 }}
              />
              <button
                onClick={() => send(input)}
                disabled={!input.trim() || loading}
                className="shrink-0 w-10 h-10 rounded-full flex items-center justify-center text-white transition-all disabled:opacity-40 disabled:cursor-not-allowed hover:opacity-90 active:scale-95"
                style={{ background: GRADIENT }}
                aria-label="Send"
              >
                <Send size={15} />
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
