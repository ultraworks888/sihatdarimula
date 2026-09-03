import { BrowserRouter, Routes, Route, Navigate, useLocation } from "react-router-dom";
import { useState, useCallback, useEffect, useRef, type ReactNode } from "react";
import { LanguageProvider } from "./contexts/LanguageContext";
import { AuthProvider, useAuth } from "./contexts/AuthContext";
import { ChildProvider } from "./contexts/ChildContext";
import SplashScreen from "./components/SplashScreen";
import Layout from "./components/Layout";
import AdminLayout from "./components/admin/AdminLayout";
import Login from "./pages/Login";
import Register from "./pages/Register";
import ForgotPassword from "./pages/ForgotPassword";
import LanguageSelect from "./pages/LanguageSelect";
import PhoneEntry from "./pages/PhoneEntry";
import Onboarding from "./pages/Onboarding";
import Home from "./pages/Home";
import Track from "./pages/Track";
import Content from "./pages/Content";
import Profile from "./pages/Profile";
import NotificationSettings from "./pages/NotificationSettings";
import NotificationHistory from "./pages/NotificationHistory";
import VerifyEmail from "./pages/VerifyEmail";
import CourseDetail from "./pages/CourseDetail";
import LessonPlayer from "./pages/LessonPlayer";
import CourseComplete from "./pages/CourseComplete";
import AdminOverview from "./pages/admin/Overview";
import AdminUsers from "./pages/admin/Users";
import AdminContent from "./pages/admin/Content";
import AdminNotifications from "./pages/admin/NotificationMonitor";
import AdminCourses from "./pages/admin/Courses";
import AdminLRS from "./pages/admin/LRS";
import AdminWhatsApp from "./pages/admin/WhatsApp";
import AdminPushBroadcast from "./pages/admin/PushBroadcast";
import AdminAnalytics from "./pages/admin/Analytics";
import AdminExport from "./pages/admin/Export";
import AdminAISettings from "./pages/admin/AISettings";
import NotFound from "./pages/NotFound";
import OneSignal from "react-onesignal";

const ONESIGNAL_APP_ID = "96071812-b067-4eaa-9083-0c68db47676e";

// Module-level flag prevents double-init in React 18 Strict Mode
let osInitialised = false;

function OneSignalInit() {
  const { user } = useAuth();
  const loggedIn = useRef<string | null>(null);

  useEffect(() => {
    if (osInitialised) return;
    osInitialised = true;
    OneSignal.init({
      appId: ONESIGNAL_APP_ID,
      notifyButton: { enable: false },
      allowLocalhostAsSecureOrigin: true,
    }).catch(() => {});
  }, []);

  useEffect(() => {
    if (user?.id && loggedIn.current !== user.id) {
      loggedIn.current = user.id;
      OneSignal.login(user.id).catch(() => {});
    } else if (!user && loggedIn.current) {
      loggedIn.current = null;
      OneSignal.logout().catch(() => {});
    }
  }, [user?.id]);

  return null;
}

function PrivateRoute({ children }: { children: ReactNode }) {
  const { user, loading } = useAuth();
  if (loading) return (
    <div className="flex items-center justify-center h-screen bg-cream">
      <div className="animate-spin rounded-full h-8 w-8 border-2 border-violet-500 border-t-transparent" />
    </div>
  );
  if (!user) return <Navigate to="/login" />;
  return <>{children}</>;
}

function RequirePhone({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const location = useLocation();
  const allowedPaths = ["/select-language", "/enter-phone"];
  if (user && !user.phone && !allowedPaths.includes(location.pathname)) {
    return <Navigate to="/enter-phone" replace />;
  }
  return <>{children}</>;
}

function AdminGuard({ children }: { children: ReactNode }) {
  const { user, loading, isAdmin } = useAuth();
  if (loading) return (
    <div className="flex items-center justify-center h-screen bg-slate-950">
      <div className="animate-spin rounded-full h-8 w-8 border-2 border-violet-500 border-t-transparent" />
    </div>
  );
  if (!user) return <Navigate to="/login" replace />;
  if (!isAdmin) return <Navigate to="/" replace />;
  return <>{children}</>;
}

function AppRoutes() {
  return (
    <Routes>
      {/* Public */}
      <Route path="/login" element={<Login />} />
      <Route path="/register" element={<Register />} />
      <Route path="/forgot-password" element={<ForgotPassword />} />
      <Route path="/verify-email" element={<VerifyEmail />} />

      {/* Auth-required pre-onboarding */}
      <Route path="/select-language" element={<PrivateRoute><LanguageSelect /></PrivateRoute>} />
      <Route path="/enter-phone" element={<PrivateRoute><PhoneEntry /></PrivateRoute>} />
      <Route path="/onboarding" element={<PrivateRoute><RequirePhone><Onboarding /></RequirePhone></PrivateRoute>} />

      {/* Lesson player + course complete — full-screen, no bottom nav */}
      <Route path="/courses/:courseId/lessons/:lessonId" element={
        <PrivateRoute><RequirePhone><LessonPlayer /></RequirePhone></PrivateRoute>
      } />
      <Route path="/courses/:courseId/complete" element={
        <PrivateRoute><RequirePhone><CourseComplete /></RequirePhone></PrivateRoute>
      } />

      {/* Main app — with Layout (header + bottom nav) */}
      <Route element={<PrivateRoute><RequirePhone><ChildProvider><Layout /></ChildProvider></RequirePhone></PrivateRoute>}>
        <Route path="/" element={<Home />} />
        <Route path="/track" element={<Track />} />
        <Route path="/content" element={<Content />} />
        <Route path="/courses/:courseId" element={<CourseDetail />} />
        <Route path="/profile" element={<Profile />} />
        <Route path="/notifications" element={<NotificationSettings />} />
        <Route path="/notification-history" element={<NotificationHistory />} />
      </Route>

      {/* Admin panel */}
      <Route element={<AdminGuard><AdminLayout /></AdminGuard>}>
        <Route path="/admin" element={<AdminOverview />} />
        <Route path="/admin/users" element={<AdminUsers />} />
        <Route path="/admin/content" element={<AdminContent />} />
        <Route path="/admin/courses" element={<AdminCourses />} />
        <Route path="/admin/lrs" element={<AdminLRS />} />
        {/* WhatsApp Templates — replaced Brevo integration with Meta Cloud API */}
        <Route path="/admin/push" element={<AdminPushBroadcast />} />
        <Route path="/admin/analytics" element={<AdminAnalytics />} />
        <Route path="/admin/export" element={<AdminExport />} />
        <Route path="/admin/whatsapp" element={<AdminWhatsApp />} />
        <Route path="/admin/notifications" element={<AdminNotifications />} />
        <Route path="/admin/ai" element={<AdminAISettings />} />
      </Route>

      <Route path="*" element={<NotFound />} />
    </Routes>
  );
}

const App = () => {
  const [splashDone, setSplashDone] = useState(false);
  const handleSplashDone = useCallback(() => setSplashDone(true), []);

  return (
    <LanguageProvider>
      {!splashDone && <SplashScreen onDone={handleSplashDone} />}
      <BrowserRouter>
        <AuthProvider>
          <OneSignalInit />
          <AppRoutes />
        </AuthProvider>
      </BrowserRouter>
    </LanguageProvider>
  );
};

export default App;
