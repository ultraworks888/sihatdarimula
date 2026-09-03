import { useEffect, useState } from "react";
import { useSearchParams, useNavigate } from "react-router-dom";
import pb from "../lib/pocketbase";
import AppLogo from "../components/AppLogo";
import { CheckCircle, XCircle } from "lucide-react";

export default function VerifyEmail() {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const token = params.get("token") ?? "";

  const [status, setStatus] = useState<"loading" | "success" | "error">("loading");
  const [message, setMessage] = useState("");

  useEffect(() => {
    if (!token) { setStatus("error"); setMessage("No verification token found. Please use the link from your email."); return; }
    (async () => {
      try {
        await pb.collection("users").confirmVerification(token);
        // Refresh auth to update verified status
        if (pb.authStore.isValid) {
          try { await pb.collection("users").authRefresh(); } catch { /* fine */ }
        }
        setStatus("success");
        setMessage("Your email has been verified successfully!");
        setTimeout(() => navigate(pb.authStore.isValid ? "/" : "/login", { replace: true }), 3000);
      } catch {
        setStatus("error");
        setMessage("This verification link is invalid or has already been used. Please request a new one from the app.");
      }
    })();
  }, [token]);

  return (
    <div className="min-h-screen bg-cream bg-mesh flex items-center justify-center p-4">
      <div className="w-full max-w-sm fade-up text-center space-y-6">
        <div className="flex justify-center"><AppLogo size={64} /></div>
        {status === "loading" && (
          <>
            <div className="animate-spin rounded-full h-10 w-10 border-2 border-violet-500 border-t-transparent mx-auto" />
            <p className="text-gray-500 text-sm">Verifying your email address...</p>
          </>
        )}
        {status === "success" && (
          <div className="glass-strong rounded-3xl p-8 space-y-4">
            <div className="w-16 h-16 mx-auto rounded-full bg-emerald-100 flex items-center justify-center">
              <CheckCircle size={32} className="text-emerald-600" />
            </div>
            <h1 className="text-xl font-bold text-gray-800">Email Verified!</h1>
            <p className="text-gray-500 text-sm">{message}</p>
            <p className="text-gray-400 text-xs">Redirecting you to the app...</p>
          </div>
        )}
        {status === "error" && (
          <div className="glass-strong rounded-3xl p-8 space-y-4">
            <div className="w-16 h-16 mx-auto rounded-full bg-rose-100 flex items-center justify-center">
              <XCircle size={32} className="text-rose-500" />
            </div>
            <h1 className="text-xl font-bold text-gray-800">Verification Failed</h1>
            <p className="text-gray-500 text-sm leading-relaxed">{message}</p>
            <button onClick={() => navigate(pb.authStore.isValid ? "/" : "/login", { replace: true })}
              className="glass-btn w-full py-3 rounded-2xl text-white font-bold text-sm">
              Back to App
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
