import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { useAuth } from "../../contexts/AuthContext";
import AppLogo from "../AppLogo";

const navItems = [
  { to: "/admin",              icon: "📊", label: "Overview",      end: true  },
  { to: "/admin/users",        icon: "👥", label: "Users",         end: false },
  { to: "/admin/analytics",    icon: "📈", label: "Analytics",     end: false },
  { to: "/admin/export",       icon: "📥", label: "Export",        end: false },
  { to: "/admin/content",      icon: "📝", label: "Content",       end: false },
  { to: "/admin/courses",      icon: "🎓", label: "Courses",       end: false },
  { to: "/admin/lrs",          icon: "🎯", label: "LRS",           end: false },
  { to: "/admin/whatsapp",     icon: "💬", label: "WA Blast",      end: false },
  { to: "/admin/push",         icon: "🔔", label: "Push",          end: false },
  { to: "/admin/notifications",icon: "📨", label: "Notifications", end: false },
  { to: "/admin/ai",           icon: "✨", label: "AI Chatbot",    end: false },
];

export default function AdminLayout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-slate-950 flex flex-col lg:flex-row">
      {/* Sidebar (desktop) */}
      <aside className="hidden lg:flex lg:flex-col w-60 shrink-0 min-h-screen sticky top-0 border-r border-white/5"
        style={{ background: "rgba(15,10,30,0.95)", backdropFilter: "blur(32px)" }}>
        {/* Logo area */}
        <div className="p-5 border-b border-white/5">
          <div className="flex items-center gap-3">
            <AppLogo size={36} />
            <div>
              <p className="text-white font-bold text-sm leading-tight">Admin</p>
              <p className="text-white/40 text-[10px]">My Healthy Start</p>
            </div>
          </div>
          <div className="mt-3 px-2 py-1 rounded-lg bg-white/5 inline-flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
            <span className="text-[10px] text-white/50 font-medium capitalize">{user?.role}</span>
          </div>
        </div>

        {/* Nav links */}
        <nav className="flex-1 p-3 space-y-0.5">
          {navItems.map(item => (
            <NavLink key={item.to} to={item.to} end={item.end}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200 ${
                  isActive
                    ? "bg-violet-600/20 text-violet-300 border border-violet-500/20"
                    : "text-white/40 hover:text-white/70 hover:bg-white/5"
                }`
              }>
              <span className="text-base">{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>

        {/* User + back */}
        <div className="p-3 border-t border-white/5 space-y-1">
          <button onClick={() => navigate("/")}
            className="w-full flex items-center gap-2.5 px-3 py-2 rounded-xl text-sm text-white/40 hover:text-white/70 hover:bg-white/5 transition-all">
            <span>🏠</span> Back to App
          </button>
          <button onClick={() => { logout(); navigate("/login"); }}
            className="w-full flex items-center gap-2.5 px-3 py-2 rounded-xl text-sm text-rose-400/70 hover:text-rose-400 hover:bg-rose-500/10 transition-all">
            <span>🚪</span> Sign Out
          </button>
          <div className="px-3 py-2 mt-1">
            <p className="text-[11px] text-white/30 truncate">{user?.email}</p>
          </div>
        </div>
      </aside>

      {/* Mobile header */}
      <header className="lg:hidden flex items-center justify-between px-4 pb-3 border-b border-white/5"
        style={{ background: "rgba(15,10,30,0.98)", paddingTop: "calc(env(safe-area-inset-top, 0px) + 12px)" }}>
        <div className="flex items-center gap-2">
          <AppLogo size={28} />
          <span className="text-white font-bold text-sm">Admin Panel</span>
        </div>
        <button onClick={() => navigate("/")} className="text-white/50 text-sm">← App</button>
      </header>

      {/* Main content */}
      <main className="flex-1 min-h-screen flex flex-col">
        {/* Top bar (desktop) */}
        <div className="hidden lg:flex items-center justify-between px-8 py-4 border-b border-white/5"
          style={{ background: "rgba(15,10,30,0.7)" }}>
          <div>
            <p className="text-white/80 text-sm font-semibold">Dashboard</p>
            <p className="text-white/30 text-xs">My Healthy Start · Admin Panel</p>
          </div>
          <div className="flex items-center gap-2 text-white/40 text-sm">
            <span>👤</span><span>{user?.name}</span>
          </div>
        </div>

        <div className="flex-1 p-4 lg:p-8">
          <Outlet />
        </div>

        {/* Mobile bottom nav */}
        <nav className="lg:hidden flex border-t border-white/5 sticky bottom-0"
          style={{ background: "rgba(15,10,30,0.98)" }}>
          {navItems.map(item => (
            <NavLink key={item.to} to={item.to} end={item.end}
              className={({ isActive }) =>
                `flex-1 flex flex-col items-center py-2.5 text-[10px] font-semibold transition-all ${
                  isActive ? "text-violet-400" : "text-white/30"
                }`
              }>
              <span className="text-lg">{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>
      </main>
    </div>
  );
}
