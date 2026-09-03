export interface Vaccine {
  name: string;
  ageMonths: number;
  description: string;
}

export const defaultVaccines: Vaccine[] = [
  { name: "BCG", ageMonths: 0, description: "Tuberculosis protection" },
  { name: "Hepatitis B - Dose 1", ageMonths: 0, description: "Birth dose" },
  { name: "DTaP - Dose 1", ageMonths: 2, description: "Diphtheria, Tetanus, Pertussis" },
  { name: "IPV - Dose 1", ageMonths: 2, description: "Polio" },
  { name: "Hib - Dose 1", ageMonths: 2, description: "Haemophilus influenzae type B" },
  { name: "PCV - Dose 1", ageMonths: 2, description: "Pneumococcal" },
  { name: "Rotavirus - Dose 1", ageMonths: 2, description: "Rotavirus gastroenteritis" },
  { name: "DTaP - Dose 2", ageMonths: 4, description: "Diphtheria, Tetanus, Pertussis" },
  { name: "IPV - Dose 2", ageMonths: 4, description: "Polio" },
  { name: "Hib - Dose 2", ageMonths: 4, description: "Haemophilus influenzae type B" },
  { name: "Rotavirus - Dose 2", ageMonths: 4, description: "Rotavirus gastroenteritis" },
  { name: "DTaP - Dose 3", ageMonths: 6, description: "Diphtheria, Tetanus, Pertussis" },
  { name: "IPV - Dose 3", ageMonths: 6, description: "Polio" },
  { name: "Hib - Dose 3", ageMonths: 6, description: "Haemophilus influenzae type B" },
  { name: "PCV - Dose 2", ageMonths: 6, description: "Pneumococcal" },
  { name: "Hepatitis B - Dose 2", ageMonths: 6, description: "Hepatitis B booster" },
  { name: "Measles - Dose 1", ageMonths: 9, description: "Measles first dose" },
  { name: "PCV - Dose 3", ageMonths: 9, description: "Pneumococcal booster" },
  { name: "MMR - Dose 1", ageMonths: 12, description: "Measles, Mumps, Rubella" },
  { name: "Varicella - Dose 1", ageMonths: 12, description: "Chickenpox" },
  { name: "Hepatitis A - Dose 1", ageMonths: 12, description: "Hepatitis A" },
  { name: "DTaP Booster", ageMonths: 18, description: "Diphtheria, Tetanus, Pertussis booster" },
  { name: "IPV Booster", ageMonths: 18, description: "Polio booster" },
  { name: "Hepatitis A - Dose 2", ageMonths: 24, description: "Hepatitis A booster" },
  { name: "MMR - Dose 2", ageMonths: 24, description: "Measles, Mumps, Rubella booster" },
  { name: "Varicella - Dose 2", ageMonths: 36, description: "Chickenpox booster" },
];
