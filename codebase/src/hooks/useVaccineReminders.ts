import { useMemo } from "react";
import { defaultVaccines, type Vaccine } from "../data/vaccines";

export interface VaccineReminder extends Vaccine {
  status: "overdue" | "due_soon" | "upcoming";
  dueDate: Date;
  childName: string;
  childId: string;
}

function getAgeInMonths(dob: string): number {
  const birth = new Date(dob);
  const now = new Date();
  return (now.getFullYear() - birth.getFullYear()) * 12 + (now.getMonth() - birth.getMonth());
}

export interface ChildForReminder {
  id: string;
  name: string;
  date_of_birth: string;
  is_born: boolean;
}

export function computeReminders(
  children: ChildForReminder[],
  completedMap: Record<string, Set<string>>
): VaccineReminder[] {
  const reminders: VaccineReminder[] = [];

  for (const child of children) {
    if (!child.is_born || !child.date_of_birth) continue;
    const ageMonths = getAgeInMonths(child.date_of_birth);
    const completed = completedMap[child.id] || new Set();
    const birthDate = new Date(child.date_of_birth);

    for (const vaccine of defaultVaccines) {
      if (completed.has(vaccine.name)) continue;

      const dueDate = new Date(birthDate);
      dueDate.setMonth(dueDate.getMonth() + vaccine.ageMonths);

      let status: VaccineReminder["status"];
      if (ageMonths > vaccine.ageMonths + 1) {
        status = "overdue";
      } else if (ageMonths >= vaccine.ageMonths - 1 && ageMonths <= vaccine.ageMonths + 1) {
        status = "due_soon";
      } else if (vaccine.ageMonths - ageMonths <= 3 && vaccine.ageMonths > ageMonths) {
        status = "upcoming";
      } else {
        continue;
      }

      reminders.push({ ...vaccine, status, dueDate, childName: child.name, childId: child.id });
    }
  }

  const priority = { overdue: 0, due_soon: 1, upcoming: 2 };
  reminders.sort((a, b) => priority[a.status] - priority[b.status] || a.dueDate.getTime() - b.dueDate.getTime());
  return reminders;
}

export function useVaccineReminders(
  children: ChildForReminder[],
  completedMap: Record<string, Set<string>>
): VaccineReminder[] {
  return useMemo(() => computeReminders(children, completedMap), [children, completedMap]);
}
