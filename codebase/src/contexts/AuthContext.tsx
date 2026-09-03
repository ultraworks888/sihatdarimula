import { createContext, useContext, useState, useEffect, type ReactNode } from "react";
import pb from "../lib/pocketbase";
import { useLang } from "./LanguageContext";
import type { Language } from "../i18n/translations";

interface User {
  id: string; email: string; name: string;
  phone: string; language: string;
  role: "user" | "admin" | "superadmin";
  verified: boolean;
}

interface AuthContextType {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string, name: string) => Promise<void>;
  logout: () => void;
  updateUser: (data: Partial<User>) => Promise<void>;
  isAdmin: boolean;
  isSuperAdmin: boolean;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}

function recordToUser(r: Record<string, unknown>): User {
  const role = String(r["role"] ?? "user");
  return {
    id: String(r.id), email: String(r.email ?? ""),
    name: String(r["name"] ?? ""), phone: String(r["phone"] ?? ""),
    language: String(r["language"] ?? ""),
    role: (role === "admin" || role === "superadmin") ? role : "user",
    verified: Boolean(r["verified"]),
  };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const { setLang } = useLang();
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  const syncLang = (u: User) => {
    if (u.language && (u.language === "en" || u.language === "ms" || u.language === "zh")) {
      setLang(u.language as Language);
    }
  };

  useEffect(() => {
    (async () => {
      try {
        if (pb.authStore.isValid) {
          const { record } = await pb.collection("users").authRefresh();
          const u = recordToUser(record as unknown as Record<string, unknown>);
          setUser(u);
          syncLang(u);
        }
      } catch { pb.authStore.clear(); }
      finally { setLoading(false); }
    })();

    const unsub = pb.authStore.onChange((_t: string, record: unknown) => {
      if (record) {
        const u = recordToUser(record as Record<string, unknown>);
        setUser(u);
      } else { setUser(null); }
    });
    return unsub;
  }, []);

  const login = async (email: string, password: string) => {
    const { record } = await pb.collection("users").authWithPassword(email, password);
    const u = recordToUser(record as unknown as Record<string, unknown>);
    setUser(u);
    syncLang(u);
  };

  const register = async (email: string, password: string, name: string) => {
    await pb.collection("users").create({ email, password, passwordConfirm: password, name });
    await pb.collection("users").authWithPassword(email, password);
  };

  const logout = () => { pb.authStore.clear(); setUser(null); };

  const updateUser = async (data: Partial<User>) => {
    if (!user) return;
    await pb.collection("users").update(user.id, data);
    setUser(prev => prev ? { ...prev, ...data } : prev);
  };

  const isAdmin = user?.role === "admin" || user?.role === "superadmin";
  const isSuperAdmin = user?.role === "superadmin";

  return (
    <AuthContext.Provider value={{ user, loading, login, register, logout, updateUser, isAdmin, isSuperAdmin }}>
      {children}
    </AuthContext.Provider>
  );
}
