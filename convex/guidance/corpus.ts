export type GuidanceDoc = {
  id: string;
  title: string;
  source: string;
  url?: string;
  tags: string[];
  body: string;
};

/**
 * Curated newborn-care snippets for Ask. Not medical advice.
 * Prefer linking parents to NHS / Lullaby Trust / midwife when unsure.
 */
export const GUIDANCE_DOCS: GuidanceDoc[] = [
  {
    id: "sleep-safe",
    title: "Safer sleep basics",
    source: "Lullaby Trust (summarised)",
    url: "https://www.lullabytrust.org.uk/safer-sleep-advice/",
    tags: ["sleep", "cot", "sids", "safer sleep", "room share"],
    body: `Babies are safest sleeping on their back on a firm, flat, waterproof mattress with no pillows, bumpers, or soft toys. Keep the sleep space clear. Room-sharing (baby in their own clear sleep space in the same room as a parent) is recommended for at least the first 6 months. Avoid smoking near baby. Never sleep on a sofa or armchair with a baby.`,
  },
  {
    id: "sleep-tog",
    title: "Room temperature and TOG layers",
    source: "Baby Steps clothing helper (Lullaby Trust-style)",
    tags: ["tog", "temperature", "clothing", "overheat", "layers", "room"],
    body: `Aim for a comfortable room around 16–20°C when possible. Use a TOG-rated bag and adjust layers rather than adding loose blankets. Feel the chest or back of the neck — warm is fine; sweaty means remove a layer. No hats or hoods for indoor sleep. Newborns and smaller babies may need one thin extra layer in cooler rooms, never at the expense of overheating.`,
  },
  {
    id: "feeding-newborn",
    title: "Newborn feeding patterns",
    source: "NHS (summarised)",
    url: "https://www.nhs.uk/baby/breastfeeding-and-bottle-feeding/",
    tags: ["feed", "breast", "bottle", "cluster", "hungry", "milk", "wake"],
    body: `Newborns often feed frequently, including overnight. Cluster feeding in the evenings is common. Responsive feeding (offer when baby shows cues) is preferred over strict schedules in the early weeks. App feed check-ins are only gentle nudges — wet and dirty nappies, settling after feeds, and steady weight gain are better signs than watching the clock alone. Young or lighter babies are often still woken for feeds; once older and thriving, many families are told they can leave longer night sleeps unless baby stirs. Seek midwife or health visitor advice if feeds are very painful, baby is unusually sleepy and hard to wake for feeds, or wet nappies drop off.`,
  },
  {
    id: "nappies",
    title: "Nappies in the early weeks",
    source: "NHS (summarised)",
    url: "https://www.nhs.uk/conditions/baby/babys-development/caring-for-a-newborn/nappies/",
    tags: ["nappy", "wee", "poo", "wet", "dirty", "mustard"],
    body: `After the first few days, expect several wet nappies a day. Breastfed poo is often runny and mustard-yellow; formula poo can be firmer and different in colour. Frequency varies widely. Contact a midwife or GP if there are fewer wet nappies than expected, blood in the stool, white or chalky stools, or baby seems unwell with nappy changes.`,
  },
  {
    id: "jaundice-flags",
    title: "Jaundice — when to seek care",
    source: "NHS (summarised)",
    url: "https://www.nhs.uk/conditions/jaundice-newborn/",
    tags: ["jaundice", "yellow", "eyes", "bilirubin"],
    body: `Mild jaundice is common in newborns. Seek urgent care advice if baby is yellow in the first 24 hours, jaundice is worsening, baby is hard to wake, not feeding well, has dark urine or pale chalky stools, or you are worried. This chat cannot diagnose jaundice — contact midwife, GP, or 111.`,
  },
  {
    id: "settling-crying",
    title: "Settling and crying",
    source: "NHS / ICON (summarised)",
    url: "https://iconcope.org/",
    tags: ["cry", "colic", "settle", "soothe", "purple crying"],
    body: `Crying peaks in the early months and can be intense (sometimes called PURPLE crying). Check basic needs: feed, nappy, temperature, wind, overstimulation. Skin-to-skin, rocking, white noise, and a calm dark room can help. Never shake a baby. If you feel overwhelmed, put baby down safely in their cot and take a short break; ask a partner or trusted adult for help. Seek care if crying comes with fever, rash, breathing difficulty, or you think something is wrong.`,
  },
  {
    id: "c-section-recovery",
    title: "After a caesarean — baby care notes",
    source: "NHS (summarised)",
    url: "https://www.nhs.uk/pregnancy/labour-and-birth/what-happens/caesarean-section/",
    tags: ["c-section", "caesarean", "delivery", "recovery", "lifting"],
    body: `After a c-section, parents may need extra help with lifting, night feeds, and positioning for feeding. Support under the baby and wound comfort matter. Follow midwife guidance on pain, wound care, and when to seek help for fever, heavy bleeding, or wound concerns. Baby feeding cues are the same; positioning may need creative support (side-lying, football hold) with midwife input.`,
  },
  {
    id: "premature-corrected",
    title: "Premature babies and corrected age",
    source: "NHS / Bliss (summarised)",
    url: "https://www.bliss.org.uk/",
    tags: ["premature", "preterm", "gestation", "corrected age"],
    body: `For babies born early, professionals often use corrected age (age from due date) for developmental expectations. Feeding, sleep, and growth patterns can differ. Follow your neonatal / health visitor plan. This chat uses any gestation you stored on the profile but does not replace specialist advice.`,
  },
  {
    id: "refuse-meds",
    title: "Medicines and dosing",
    source: "Baby Steps safety policy",
    tags: ["medicine", "calpol", "paracetamol", "ibuprofen", "dose", "medication"],
    body: `Baby Steps Ask will not give medicine names with doses, schedules, or whether a medicine is appropriate. For fever, pain, or illness, contact a pharmacist, GP, midwife, or NHS 111. In an emergency call 999.`,
  },
  {
    id: "emergencies",
    title: "When to get urgent help",
    source: "NHS (summarised)",
    url: "https://www.nhs.uk/conditions/baby/caring-for-a-newborn/baby-first-aid/",
    tags: ["emergency", "breathing", "blue", "floppy", "unresponsive", "111", "999"],
    body: `Get emergency help (999) if a baby is not breathing normally, is blue/grey, unresponsive, or having a seizure. Use NHS 111 for urgent advice when unsure. This chat cannot triage emergencies.`,
  },
];

function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((t) => t.length > 2);
}

export function searchGuidance(query: string, limit = 4): GuidanceDoc[] {
  const tokens = tokenize(query);
  if (tokens.length === 0) {
    return GUIDANCE_DOCS.slice(0, limit);
  }
  const scored = GUIDANCE_DOCS.map((doc) => {
    const hay = tokenize(`${doc.title} ${doc.tags.join(" ")} ${doc.body}`).join(" ");
    let score = 0;
    for (const token of tokens) {
      if (doc.tags.some((t) => t.includes(token) || token.includes(t))) score += 3;
      if (doc.title.toLowerCase().includes(token)) score += 2;
      if (hay.includes(token)) score += 1;
    }
    return { doc, score };
  });
  scored.sort((a, b) => b.score - a.score);
  const hits = scored.filter((s) => s.score > 0).slice(0, limit);
  return (hits.length > 0 ? hits : scored.slice(0, limit)).map((s) => s.doc);
}
