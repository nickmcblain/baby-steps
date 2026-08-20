export type ClothingAdvice = {
  tog: string;
  layers: string[];
  why: string;
  overheat: boolean;
  extraLayer: boolean;
};

function ageDays(dateOfBirth: number, now: number): number {
  return Math.max(0, Math.floor((now - dateOfBirth) / 86_400_000));
}

type Band = {
  maxTemp: number;
  tog: string;
  layers: string[];
  why: string;
};

const BANDS: Band[] = [
  {
    maxTemp: 16,
    tog: "2.5 TOG",
    layers: ["Vest", "Sleepsuit", "2.5 TOG bag", "Light cellular blanket if still cool"],
    why: "A cool room needs a thicker bag and full layers.",
  },
  {
    maxTemp: 18,
    tog: "2.5 TOG",
    layers: ["Vest", "Sleepsuit", "2.5 TOG sleeping bag"],
    why: "On the cool side of the usual 16–20°C range.",
  },
  {
    maxTemp: 20,
    tog: "1.0 TOG",
    layers: ["Vest", "Sleepsuit or 1.0 TOG bag"],
    why: "This is the typical comfortable nursery band.",
  },
  {
    maxTemp: 22,
    tog: "1.0 TOG",
    layers: ["Vest", "1.0 TOG bag or light sleepsuit"],
    why: "Warm enough that a light bag over a vest is plenty.",
  },
  {
    maxTemp: 24,
    tog: "0.5 TOG",
    layers: ["Vest", "0.5 TOG bag or sheet"],
    why: "A warm room — keep bedding light.",
  },
  {
    maxTemp: 100,
    tog: "0.2 TOG",
    layers: ["Nappy", "Short-sleeve vest if needed"],
    why: "At 24°C and above, babies overheat easily. Less is safer.",
  },
];

export function clothingAdvice(args: {
  tempC: number;
  dateOfBirth: number;
  weightGrams: number;
  now?: number;
}): ClothingAdvice {
  const now = args.now ?? Date.now();
  const days = ageDays(args.dateOfBirth, now);
  const extraLayer = days < 92 || args.weightGrams < 5000;
  const band = BANDS.find((item) => args.tempC < item.maxTemp) ?? BANDS[BANDS.length - 1];
  const layers = [...band.layers];
  if (extraLayer && args.tempC < 24) {
    layers.unshift("Extra vest (newborn / smaller baby)");
  }
  const overheat = args.tempC >= 22;
  return {
    tog: band.tog,
    layers,
    why: extraLayer
      ? `${band.why} Under 3 months or a lighter baby can use one extra thin layer — never a hat indoors.`
      : band.why,
    overheat,
    extraLayer,
  };
}
