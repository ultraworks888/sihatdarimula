import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from "react";
import pb from "../lib/pocketbase";
import { useAuth } from "./AuthContext";

export interface Child {
  id: string;
  name: string;
  date_of_birth: string;
  due_date: string;
  gender: string;
  is_born: boolean;
}

interface ChildContextType {
  children: Child[];
  selectedChild: Child | null;
  selectChild: (id: string) => void;
  addChild: (data: Partial<Child>) => Promise<void>;
  removeChild: (id: string) => Promise<void>;
  loading: boolean;
  refresh: () => Promise<void>;
}

const ChildContext = createContext<ChildContextType | null>(null);

export function useChild() {
  const ctx = useContext(ChildContext);
  if (!ctx) throw new Error("useChild must be used within ChildProvider");
  return ctx;
}

export function ChildProvider({ children: kids }: { children: ReactNode }) {
  const { user } = useAuth();
  const [children, setChildren] = useState<Child[]>([]);
  const [selectedChild, setSelectedChild] = useState<Child | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchChildren = useCallback(async () => {
    if (!user) { setLoading(false); return; }
    const result = await pb.collection("children").getFullList({
      filter: pb.filter("user = {:userId}", { userId: user.id }),
      sort: "created",
      requestKey: null,
    });
    const mapped: Child[] = result.map(r => ({
      id: r.id,
      name: String(r["name"]),
      date_of_birth: String(r["date_of_birth"] ?? ""),
      due_date: String(r["due_date"] ?? ""),
      gender: String(r["gender"] ?? ""),
      is_born: Boolean(r["is_born"]),
    }));
    setChildren(mapped);
    setSelectedChild(prev => {
      if (prev && mapped.find(c => c.id === prev.id)) return prev;
      return mapped[0] || null;
    });
    setLoading(false);
  }, [user]);

  useEffect(() => { fetchChildren(); }, [fetchChildren]);

  const selectChild = (id: string) => {
    const child = children.find(c => c.id === id);
    if (child) setSelectedChild(child);
  };

  const addChild = async (data: Partial<Child>) => {
    if (!user) return;
    await pb.collection("children").create({ ...data, user: user.id });
    await fetchChildren();
  };

  const removeChild = async (id: string) => {
    await pb.collection("children").delete(id);
    if (selectedChild?.id === id) setSelectedChild(null);
    await fetchChildren();
  };

  return (
    <ChildContext.Provider value={{ children, selectedChild, selectChild, addChild, removeChild, loading, refresh: fetchChildren }}>
      {kids}
    </ChildContext.Provider>
  );
}
