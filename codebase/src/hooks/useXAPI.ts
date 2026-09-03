import pb from "../lib/pocketbase";
import { useAuth } from "../contexts/AuthContext";
import { addToOfflineQueue } from "./useOfflineSync";

export type XAPIVerb = "initialized" | "progressed" | "completed" | "paused" | "resumed" | "passed" | "failed" | "abandoned";
export type XAPIObjectType = "lesson" | "course" | "quiz";

export interface XAPIResult {
  completion?: boolean;
  success?: boolean;
  score?: number;
  duration?: number;
  progress?: number;
}

export function useXAPI() {
  const { user } = useAuth();

  const record = async (
    verb: XAPIVerb,
    objectType: XAPIObjectType,
    objectId: string,
    result?: XAPIResult,
  ) => {
    if (!user) return;

    const statement = {
      user: user.id,
      verb,
      object_type: objectType,
      object_id: objectId,
      result_completion: result?.completion ?? false,
      result_success: result?.success ?? false,
      result_score: result?.score ?? 0,
      result_duration: result?.duration ?? 0,
      result_progress: result?.progress ?? 0,
      context_json: { userAgent: navigator.userAgent },
      statement_timestamp: new Date().toISOString().replace("T", " ").slice(0, 23) + "Z",
      synced_offline: false,
    };

    if (!navigator.onLine) {
      await addToOfflineQueue({ ...statement, synced_offline: true });
      return;
    }

    try {
      await pb.collection("xapi_statements").create(statement);
    } catch {
      await addToOfflineQueue({ ...statement, synced_offline: true });
    }
  };

  return { record };
}
