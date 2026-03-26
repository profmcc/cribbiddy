import * as cards from "./cards.ts";
import * as scoring from "./scoring.ts";
import * as ui from "./ui.ts";
import * as data from "./data/index.ts";
import * as balatrMode from "./game_modes/balatro_mode.ts";

const GOAL_SCORE = 121;
const CUT_CLEAR_ABOVE = 0.25;
const CUT_DROP = 0.4;
const CUT_REVEAL = 1.3;
const CUT_CLEAR_BELOW = 0.25;
const CUT_SLIDE = 0.5;

const USE_BALATRO_MODE = true;

// ---------------------------------------------------------------------------
// Helper: set both fillStyle and strokeStyle
// ---------------------------------------------------------------------------
function setColor(
  ctx: CanvasRenderingContext2D,
  r: number,
  g: number,
  b: number,
  a: number = 1
): void {
  const style = `rgba(${Math.round(r * 255)},${Math.round(g * 255)},${Math.round(b * 255)},${a})`;
  ctx.fillStyle = style;
  ctx.strokeStyle = style;
}

// ---------------------------------------------------------------------------
// Helper: draw a filled rounded-rectangle
// ---------------------------------------------------------------------------
function fillRoundedRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  rx: number
): void {
  ctx.beginPath();
  ctx.moveTo(x + rx, y);
  ctx.lineTo(x + w - rx, y);
  ctx.arcTo(x + w, y, x + w, y + rx, rx);
  ctx.lineTo(x + w, y + h - rx);
  ctx.arcTo(x + w, y + h, x + w - rx, y + h, rx);
  ctx.lineTo(x + rx, y + h);
  ctx.arcTo(x, y + h, x, y + h - rx, rx);
  ctx.lineTo(x, y + rx);
  ctx.arcTo(x, y, x + rx, y, rx);
  ctx.closePath();
  ctx.fill();
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type SideEffects = {
  draw_bonus: number;
  redraw_next_hand: boolean;
  fifteens_bonus: number;
  pairs_bonus: number;
  runs_bonus: number;
  remove_crib_card: boolean;
  hand_size_bonus: number;
  extra_shop_action: number;
  next_score_multiplier: number;
  moonshine_active: boolean;
  peek_cut: boolean;
  pretzels: boolean;
  show_ai_hand: boolean;
  flooded: boolean;
  current_map: Record<string, string> | null;
  tea: boolean;
  coconut: boolean;
  hot_cocoa: boolean;
  sunscreen: boolean;
  seaweed_wrap: boolean;
  cloud_candy: boolean;
  mushroom: boolean;
  kelp_chips: boolean;
  freeze_dried_meal: boolean;
  oxygen_tank: boolean;
  raw_meat: boolean;
  sake: boolean;
  mochi: boolean;
};

export type Meta = {
  board_id: string;
  street: number;
  money: number;
  family_slots: number;
  family: any[];
  side_pouch: any[];
  side_pouch_capacity: number;
  completed_streets: Record<string, Record<number, boolean>>;
  deck_counts: Record<string, number>;
  enhancements: Record<string, string>;
  special_pouch: any[];
  special_pouch_capacity: number;
  graveyard: Array<{ id: string; count: number }>;
  side_effects: SideEffects;
  temp_family: any[];
  orbit_queue: Array<{ id: string; turns: number }>;
};

export type GameState = {
  phase: string;
  level: number;
  player_score: number;
  ai_score: number;
  dealer: "player" | "ai";
  message: string;
  last_score_event: string;
  round: number;
  history: string[];
  history_written: boolean;
  meta: Meta;
  deck?: any[];
  player_hand?: any[];
  ai_hand?: any[];
  player_show_hand?: any[];
  ai_show_hand?: any[];
  player_peg_hand?: any[];
  ai_peg_hand?: any[];
  crib?: any[];
  starter?: any;
  discard_selection?: Record<number, boolean>;
  discard_overlimit_at?: number | null;
  turn?: string;
  peg?: {
    count: number;
    stack: any[];
    last_player: string | null;
    player_passed: boolean;
    ai_passed: boolean;
  };
  pending_pass_key?: string | null;
  show_details?: any;
  cut?: any;
  shop?: any;
  preview?: any;
  special_use?: any;
  side_dish_use?: any;
  deck_view_page?: number;
  view_prev?: string;
  phase_before_map?: string;
  peek_cut_card_label?: string | null;
};

// ---------------------------------------------------------------------------
// Module-level state (not exported)
// ---------------------------------------------------------------------------
let state: GameState = {} as GameState;

// ---------------------------------------------------------------------------
// Forward declarations (hoisted via let + reassignment pattern)
// ---------------------------------------------------------------------------
let logEvent: (message: string) => void;
let writeHistory: () => void;
let startPegging: () => void;
let awardPoints: (target: string, points: number, reason: string) => void;

// ---------------------------------------------------------------------------
// Pure helpers
// ---------------------------------------------------------------------------

function copyList<T>(list: T[]): T[] {
  return list.slice();
}

function appendCard(list: any[], card: any): any[] {
  return [...list, card];
}

function toggleDealer(current: string): "player" | "ai" {
  return current === "player" ? "ai" : "player";
}

function currentBoard(): any {
  return (data as any).boards.boards[state.meta.board_id];
}

function currentStreet(): any {
  const board = currentBoard();
  if (!board) return null;
  // Lua streets are 1-indexed; state.meta.street is 1-based
  return board.streets[state.meta.street - 1];
}

function nextStreet(): any {
  const board = currentBoard();
  if (!board) return null;
  return board.streets[state.meta.street]; // state.meta.street is 1-based, so +1 in JS = [street]
}

function markStreetComplete(): void {
  const board_id = state.meta.board_id;
  const street = currentStreet();
  if (!street) return;
  if (!state.meta.completed_streets[board_id]) {
    state.meta.completed_streets[board_id] = {};
  }
  state.meta.completed_streets[board_id][street.id] = true;
}

function countSelected(selection: Record<number, boolean>): number {
  let count = 0;
  for (const key of Object.keys(selection)) {
    if ((selection as any)[key]) count++;
  }
  return count;
}

function removeIndices(list: any[], indices: number[]): any[] {
  // indices are 1-based
  indices.sort((a, b) => b - a);
  const removed: any[] = [];
  for (const index of indices) {
    removed.push(list.splice(index - 1, 1)[0]);
  }
  return removed;
}

function aiChooseDiscard(hand: any[]): number[] {
  const indexed = hand.map((card, i) => ({
    index: i + 1, // 1-based
    value: (cards as any).card_value(card),
  }));
  indexed.sort((a, b) => {
    if (a.value === b.value) return a.index - b.index;
    return a.value - b.value;
  });
  return [indexed[0].index, indexed[1].index];
}

function aiChoosePlay(hand: any[], count: number, stack: any[]): number | null {
  let bestIndex: number | null = null;
  let bestPoints = -1;
  let bestValue = 99;
  for (let i = 0; i < hand.length; i++) {
    const card = hand[i];
    if ((cards as any).card_value(card) + count <= 31) {
      const points = (scoring as any).pegging_points_for_play(stack, card, count);
      const value = (cards as any).card_value(card);
      if (points > bestPoints || (points === bestPoints && value < bestValue)) {
        bestPoints = points;
        bestIndex = i + 1; // 1-based
        bestValue = value;
      }
    }
  }
  return bestIndex;
}

// ---------------------------------------------------------------------------
// Card-count helpers
// ---------------------------------------------------------------------------

function removeCardId(card_id: string, amount: number): number {
  const current = state.meta.deck_counts[card_id] || 0;
  const toRemove = Math.min(current, amount);
  if (toRemove <= 0) return 0;
  if (!canDelete(toRemove)) return 0;
  state.meta.deck_counts[card_id] = current - toRemove;
  if (state.meta.deck_counts[card_id] <= 0) {
    delete state.meta.deck_counts[card_id];
  }
  state.meta.graveyard.push({ id: card_id, count: toRemove });
  return toRemove;
}

function rankMatches(card_id: string, targetRank: number): boolean {
  const m = card_id.match(/^([^-]+)-.+$/);
  if (!m) return false;
  return (cards as any).rank_from_name(m[1]) === targetRank;
}

function suitMatches(card_id: string, suitName: string): boolean {
  const m = card_id.match(/^.+-(.+)$/);
  return m ? m[1] === suitName : false;
}

function deleteOneCard(card: any): number {
  return removeCardId((cards as any).card_id(card), 1);
}

function deleteRank(card: any, limit: number | null, onlyUnenhanced: boolean): number {
  const targetRank = card.rank;
  let deleted = 0;
  for (const [card_id, count] of Object.entries(state.meta.deck_counts)) {
    if (rankMatches(card_id, targetRank)) {
      if (!onlyUnenhanced || !state.meta.enhancements[card_id]) {
        const remaining = limit !== null ? limit - deleted : (count as number);
        if (remaining <= 0) break;
        const removed = removeCardId(card_id, remaining);
        deleted += removed;
        if (limit !== null && deleted >= limit) break;
      }
    }
  }
  return deleted;
}

function deleteSuit(card: any): number {
  const targetSuit = (cards as any).suit_name(card.suit);
  let deleted = 0;
  for (const [card_id, count] of Object.entries(state.meta.deck_counts)) {
    if (suitMatches(card_id, targetSuit)) {
      const removed = removeCardId(card_id, count as number);
      deleted += removed;
    }
  }
  return deleted;
}

function deckSize(): number {
  let total = 0;
  for (const count of Object.values(state.meta.deck_counts)) {
    total += count as number;
  }
  return total;
}

function canDelete(count: number): boolean {
  return deckSize() - count >= 40;
}

function canAddCard(card_id: string, amount: number): boolean {
  const total = deckSize() + amount;
  if (total > 60) return false;
  const current = state.meta.deck_counts[card_id] || 0;
  if (current + amount > 6) return false;
  return true;
}

function addCardId(card_id: string, amount: number): boolean {
  if (!canAddCard(card_id, amount)) return false;
  state.meta.deck_counts[card_id] = (state.meta.deck_counts[card_id] || 0) + amount;
  return true;
}

function replaceCardId(old_id: string, new_id: string): boolean {
  const current = state.meta.deck_counts[old_id] || 0;
  if (current <= 0) return false;
  if (!canAddCard(new_id, 1)) return false;
  state.meta.deck_counts[old_id] = current - 1;
  if (state.meta.deck_counts[old_id] <= 0) {
    delete state.meta.deck_counts[old_id];
  }
  state.meta.deck_counts[new_id] = (state.meta.deck_counts[new_id] || 0) + 1;
  if (state.meta.enhancements[old_id]) {
    state.meta.enhancements[new_id] = state.meta.enhancements[old_id];
    delete state.meta.enhancements[old_id];
  }
  return true;
}

function isPrehistoric(card: any): boolean {
  return card.rank === 0 || card.rank === 14 || card.rank === 15;
}

function applyCurrentToCard(card: any): void {
  const map = state.meta.side_effects.current_map;
  if (!map) return;
  const suitName = (cards as any).suit_name(card.suit);
  const mapped = map[suitName];
  if (mapped) {
    for (let i = 1; i <= 4; i++) {
      if ((cards as any).suit_name(i) === mapped) {
        card.suit = i;
        return;
      }
    }
  }
}

function applyVisibility(hand: any[], visibleCount: number | null): void {
  if (visibleCount === null || visibleCount === undefined) return;
  if (visibleCount >= hand.length) return;
  for (let i = 0; i < hand.length; i++) {
    hand[i].hidden = true;
  }
  const indices = hand.map((_, i) => i);
  const count = Math.max(0, visibleCount);
  for (let k = 0; k < count; k++) {
    const pick = Math.floor(Math.random() * indices.length);
    const index = indices.splice(pick, 1)[0];
    hand[index].hidden = false;
  }
}

function enqueueOrbit(card_id: string, turns: number): void {
  state.meta.orbit_queue.push({ id: card_id, turns });
}

function processOrbitReturns(): void {
  const remaining: Array<{ id: string; turns: number }> = [];
  for (const entry of state.meta.orbit_queue) {
    entry.turns = entry.turns - 1;
    if (entry.turns <= 0) {
      addCardId(entry.id, 1);
    } else {
      remaining.push(entry);
    }
  }
  state.meta.orbit_queue = remaining;
}

function cardIdFor(rank: number, suitIndex: number): string {
  return (cards as any).rank_name(rank) + "-" + (cards as any).suit_name(suitIndex);
}

// ---------------------------------------------------------------------------
// Random helpers
// ---------------------------------------------------------------------------

function randomInt(n: number): number {
  return Math.floor(Math.random() * n) + 1;
}

function randomIntRange(m: number, n: number): number {
  return Math.floor(Math.random() * (n - m + 1)) + m;
}

function randomChoice<T>(list: T[]): T | null {
  if (!list || list.length === 0) return null;
  return list[Math.floor(Math.random() * list.length)];
}

function pickFromGroups(groups: any[]): any {
  const options: any[] = [];
  for (const group of groups) {
    for (const item of group.items) {
      options.push(item);
    }
  }
  return randomChoice(options);
}

function pickAuntieUncle(): any {
  const roll = Math.random();
  if (roll <= 0.6) {
    return pickFromGroups((data as any).aunties.universal);
  } else if (roll <= 0.9) {
    const boardSpecific = (data as any).aunties.board_specific[state.meta.board_id] || [];
    return randomChoice(boardSpecific) || pickFromGroups((data as any).aunties.universal);
  }
  const unlocked = (data as any).boards.unlock_tree[state.meta.board_id] || [];
  const adjacent = randomChoice(unlocked);
  if (adjacent && (data as any).aunties.board_specific[adjacent]) {
    return randomChoice((data as any).aunties.board_specific[adjacent]);
  }
  return pickFromGroups((data as any).aunties.universal);
}

function pickSideDish(): any {
  const roll = Math.random();
  if (roll <= 0.7) {
    return randomChoice((data as any).side_dishes.universal);
  } else if (roll <= 0.95) {
    const boardSpecific = (data as any).side_dishes.board_specific[state.meta.board_id] || [];
    return randomChoice(boardSpecific) || randomChoice((data as any).side_dishes.universal);
  }
  const unlocked = (data as any).boards.unlock_tree[state.meta.board_id] || [];
  const adjacent = randomChoice(unlocked);
  if (adjacent && (data as any).side_dishes.board_specific[adjacent]) {
    return randomChoice((data as any).side_dishes.board_specific[adjacent]);
  }
  return randomChoice((data as any).side_dishes.universal);
}

function buildShopStock(): [any[], any[]] {
  const familyStock: any[] = [];
  const dishStock: any[] = [];
  const familyCount = randomIntRange(3, 5);
  const dishCount = randomIntRange(3, 5);
  for (let i = 0; i < familyCount; i++) {
    familyStock.push(pickAuntieUncle());
  }
  for (let i = 0; i < dishCount; i++) {
    dishStock.push(pickSideDish());
  }
  return [familyStock, dishStock];
}

// ---------------------------------------------------------------------------
// Logging
// ---------------------------------------------------------------------------

logEvent = function (message: string): void {
  if (!state.history) return;
  const stamp = new Date().toISOString();
  const phase = state.phase || "unknown";
  const street = state.meta && state.meta.street ? state.meta.street : "?";
  state.history.push(`[${stamp}][Street ${street}][${phase}] ${message}`);
};

writeHistory = function (): void {
  if (state.history_written) return;
  state.history_written = true;
  const filename = "cribbiddy_history_" + Date.now() + ".txt";
  const content = (state.history || []).join("\n");
  localStorage.setItem(filename, content);
  state.message = "History saved to localStorage/" + filename;
};

// ---------------------------------------------------------------------------
// Deck view helpers
// ---------------------------------------------------------------------------

function currentDeckForView(): any[] {
  return (cards as any).build_deck({
    board_id: state.meta.board_id,
    deck_counts: state.meta.deck_counts,
    enhancements: state.meta.enhancements,
  });
}

function enhancementShopList(): any[] {
  return (data as any).boards.shop_structure.card_enhancements;
}

function deckPage(deck: any[], page: number, perPage: number): [any[], number] {
  const startIdx = (page - 1) * perPage; // 0-based
  const items: any[] = [];
  for (let i = startIdx; i < Math.min(deck.length, startIdx + perPage); i++) {
    items.push(deck[i]);
  }
  return [items, startIdx + 1]; // return 1-based start for display
}

function listPage(list: any[], page: number, perPage: number): [any[], number] {
  const startIdx = (page - 1) * perPage;
  const items: any[] = [];
  for (let i = startIdx; i < Math.min(list.length, startIdx + perPage); i++) {
    items.push(list[i]);
  }
  return [items, startIdx + 1];
}

function deckEntries(): any[] {
  const entries: any[] = [];
  for (const [card_id, count] of Object.entries(state.meta.deck_counts)) {
    const m = card_id.match(/^([^-]+)-(.+)$/);
    const rankName = m ? m[1] : "?";
    const suitName = m ? m[2] : "?";
    const label = rankName + suitName;
    entries.push({
      id: card_id,
      label,
      count,
      rank: (cards as any).rank_from_name(rankName) || 0,
      suit: suitName,
      enhancement: state.meta.enhancements[card_id],
    });
  }
  entries.sort((a, b) => {
    if (a.suit === b.suit) return a.rank - b.rank;
    return a.suit < b.suit ? -1 : 1;
  });
  return entries;
}

// ---------------------------------------------------------------------------
// Side dish effects
// ---------------------------------------------------------------------------

function applySideDishEffect(dish: any): boolean {
  if (dish.id === "cake") {
    state.meta.money += 5;
    logEvent("Cake: +$5.");
    return true;
  }
  if (dish.id === "hot_dog") {
    state.player_score += 3;
    logEvent("Hot Dog: +3 pegs.");
    return true;
  }
  if (dish.id === "coffee") {
    state.meta.side_effects.draw_bonus += 2;
    logEvent("Coffee: draw +2 next hand.");
    return true;
  }
  if (dish.id === "espresso") {
    state.meta.side_effects.extra_shop_action += 1;
    logEvent("Espresso: extra shop action.");
    return true;
  }
  if (dish.id === "joint") {
    state.meta.side_effects.redraw_next_hand = true;
    logEvent("Joint: redraw next hand.");
    return true;
  }
  if (dish.id === "cookies") {
    state.meta.side_effects.fifteens_bonus += 1;
    logEvent("Cookies: +1 per fifteen this hand.");
    return true;
  }
  if (dish.id === "lemonade") {
    state.meta.side_effects.remove_crib_card = true;
    logEvent("Lemonade: remove one crib card before scoring against you.");
    return true;
  }
  if (dish.id === "nachos") {
    state.meta.side_effects.pairs_bonus += 1;
    logEvent("Nachos: +1 per pair this hand.");
    return true;
  }
  if (dish.id === "moonshine") {
    state.meta.side_effects.next_score_multiplier = 2;
    state.meta.side_effects.moonshine_active = true;
    logEvent("Moonshine: next score doubled, one family will leave.");
    return true;
  }
  if (dish.id === "popcorn") {
    state.meta.side_effects.peek_cut = true;
    logEvent("Popcorn: peek cut card before discard.");
    return true;
  }
  if (dish.id === "pretzels") {
    state.meta.side_effects.pretzels = true;
    logEvent("Pretzels: swap a card with crib after discard.");
    return true;
  }
  if (dish.id === "wings") {
    state.meta.side_effects.runs_bonus += 1;
    logEvent("Wings: +1 per run card this hand.");
    return true;
  }
  if (dish.id === "casserole") {
    const temp = pickAuntieUncle();
    if (temp) {
      temp.temp = true;
      state.meta.family.push(temp);
      state.meta.temp_family.push(temp);
      logEvent("Casserole: temporary family " + temp.name + ".");
      return true;
    }
    return false;
  }
  if (dish.id === "sushi") {
    state.meta.side_effects.show_ai_hand = true;
    logEvent("Sushi: reveal opponent pegging hand.");
    return true;
  }
  if (dish.id === "tea") {
    state.meta.side_effects.tea = true;
    logEvent("Tea: remove one negative condition (not yet implemented).");
    return true;
  }
  if (dish.id === "water") {
    const last = state.meta.graveyard[state.meta.graveyard.length - 1];
    if (!last) return false;
    if (!addCardId(last.id, 1)) return false;
    last.count -= 1;
    if (last.count <= 0) {
      state.meta.graveyard.pop();
    }
    logEvent("Water: restored " + last.id + ".");
    return true;
  }
  if (dish.id === "edible") {
    const list = (data as any).side_dishes.universal;
    let pick = list[Math.floor(Math.random() * list.length)];
    if (pick.id === "edible") {
      pick = list[Math.floor(Math.random() * (list.length - 1))];
    }
    logEvent("Edible: triggered " + pick.name + ".");
    return applySideDishEffect(pick);
  }
  if (dish.id === "coconut") {
    state.meta.side_effects.coconut = true;
    logEvent("Coconut: vined cards freed (not yet implemented).");
    return true;
  }
  if (dish.id === "trail_mix") {
    state.meta.side_effects.hand_size_bonus += 1;
    logEvent("Trail Mix: +1 hand size this Street.");
    return true;
  }
  if (dish.id === "hot_cocoa") {
    state.meta.side_effects.hot_cocoa = true;
    logEvent("Hot Cocoa: frostbitten scores half (not yet implemented).");
    return true;
  }
  if (dish.id === "sunscreen") {
    state.meta.side_effects.sunscreen = true;
    logEvent("Sunscreen: tide roll treated as 2 lower (not yet implemented).");
    return true;
  }
  if (dish.id === "seaweed_wrap") {
    state.meta.side_effects.seaweed_wrap = true;
    logEvent("Seaweed Wrap: washed-away card returns (not yet implemented).");
    return true;
  }
  if (dish.id === "cloud_candy") {
    state.meta.side_effects.cloud_candy = true;
    logEvent("Cloud Candy: cloudwalk swaps +1 (not yet implemented).");
    return true;
  }
  if (dish.id === "mushroom") {
    state.meta.side_effects.mushroom = true;
    logEvent("Mushroom: see +2 extra cards in darkness (not yet implemented).");
    return true;
  }
  if (dish.id === "kelp_chips") {
    state.meta.side_effects.kelp_chips = true;
    logEvent("Kelp Chips: currents don't affect this hand (not yet implemented).");
    return true;
  }
  if (dish.id === "freeze_dried_meal") {
    state.meta.side_effects.freeze_dried_meal = true;
    logEvent("Freeze-Dried Meal: orbit returns immediately (not yet implemented).");
    return true;
  }
  if (dish.id === "oxygen_tank") {
    state.meta.side_effects.oxygen_tank = true;
    logEvent("Oxygen Tank: supply drop guaranteed (not yet implemented).");
    return true;
  }
  if (dish.id === "raw_meat") {
    state.meta.side_effects.raw_meat = true;
    logEvent("Raw Meat: prehistoric cards score triple this hand.");
    return true;
  }
  if (dish.id === "sake") {
    state.meta.side_effects.sake = true;
    logEvent("Sake: next Kata requirement -1 (not yet implemented).");
    return true;
  }
  if (dish.id === "mochi") {
    state.meta.side_effects.mochi = true;
    logEvent("Mochi: Kata gives +$3 (not yet implemented).");
    return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Special card / side dish use flows
// ---------------------------------------------------------------------------

function beginSpecialUse(context: string, specialIndex: number = 1): void {
  state.special_use = {
    page: 1,
    context,
    special_index: specialIndex,
    message: "Pick a card to use " + state.meta.special_pouch[specialIndex - 1].name + ".",
  };
  state.phase = "special_use";
}

function beginSideDishUse(context: string, dish: any): void {
  state.side_dish_use = {
    page: 1,
    context,
    dish,
    message: "Pick a card for " + dish.name + ".",
  };
  state.phase = "side_dish_use";
}

function handleSideDishUseInput(key: string): void {
  if (key === "b") {
    state.phase = state.side_dish_use.context;
    state.side_dish_use = null;
    return;
  }
  if (key === "n") {
    state.side_dish_use.page += 1;
    return;
  }
  if (key === "p" && state.side_dish_use.page > 1) {
    state.side_dish_use.page -= 1;
    return;
  }
  const index = parseInt(key, 10);
  if (isNaN(index)) return;
  const deck = currentDeckForView();
  const perPage = 9;
  const [pageItems] = deckPage(deck, state.side_dish_use.page, perPage);
  const card = pageItems[index - 1]; // index is 1-based from display
  if (!card) return;
  const dish = state.side_dish_use.dish;
  const card_id = (cards as any).card_id(card);
  if (dish.id === "beer") {
    if (card.rank < 11 || card.rank > 13) {
      state.side_dish_use.message = "Pick a face card (J/Q/K).";
      return;
    }
    const newId = cardIdFor(10, card.suit);
    if (!replaceCardId(card_id, newId)) {
      state.side_dish_use.message = "Cannot downgrade this card.";
      return;
    }
    logEvent("Beer downgraded " + (cards as any).card_label(card) + " to 10.");
  } else if (dish.id === "wine") {
    if (card.rank < 2 || card.rank > 10) {
      state.side_dish_use.message = "Pick a number card (2-10).";
      return;
    }
    let newRank = card.rank + 2;
    if (newRank > 13) newRank = 13;
    const newId = cardIdFor(newRank, card.suit);
    if (!replaceCardId(card_id, newId)) {
      state.side_dish_use.message = "Cannot upgrade this card.";
      return;
    }
    logEvent(
      "Wine upgraded " +
        (cards as any).card_label(card) +
        " to " +
        (cards as any).rank_name(newRank) +
        (cards as any).suit_name(card.suit) +
        "."
    );
  } else if (dish.id === "whiskey") {
    if (!canDelete(1)) {
      state.side_dish_use.message = "Cannot destroy (min deck size 40).";
      return;
    }
    removeCardId(card_id, 1);
    state.player_score += 10;
    logEvent("Whiskey destroyed " + (cards as any).card_label(card) + " (+10 pegs).");
  } else if (dish.id === "pie") {
    if (!addCardId(card_id, 1)) {
      state.side_dish_use.message = "Cannot duplicate (max copies/deck size).";
      return;
    }
    logEvent("Pie duplicated " + (cards as any).card_label(card) + ".");
  } else {
    state.side_dish_use.message = "This dish isn't implemented yet.";
    return;
  }
  state.side_dish_use = null;
  state.phase = state.view_prev || "street_preview";
}

function handleSpecialUseInput(key: string): void {
  if (key === "b") {
    state.phase = state.special_use.context;
    state.special_use = null;
    return;
  }
  if (key === "n") {
    state.special_use.page += 1;
    return;
  }
  if (key === "p" && state.special_use.page > 1) {
    state.special_use.page -= 1;
    return;
  }
  const index = parseInt(key, 10);
  if (isNaN(index)) return;
  const deck = currentDeckForView();
  const perPage = 9;
  const [pageItems] = deckPage(deck, state.special_use.page, perPage);
  const card = pageItems[index - 1];
  if (!card) return;
  const special = state.meta.special_pouch[state.special_use.special_index - 1];
  let deleted = 0;
  if (special.id === "eraser") {
    deleted = deleteOneCard(card);
  } else if (special.id === "purge") {
    deleted = deleteRank(card, 3, false);
  } else if (special.id === "cleanse") {
    deleted = deleteSuit(card);
  } else if (special.id === "cull") {
    deleted = deleteRank(card, null, true);
  } else {
    state.special_use.message = "This special card isn't implemented yet.";
    return;
  }
  if (deleted <= 0) {
    state.special_use.message = "Cannot delete (min deck size 40).";
    return;
  }
  state.meta.special_pouch.splice(state.special_use.special_index - 1, 1);
  logEvent(
    "Used " +
      special.name +
      " on " +
      (cards as any).card_label(card) +
      " (removed " +
      deleted +
      ")."
  );
  const returnPhase = state.special_use.context;
  state.special_use = null;
  state.phase = returnPhase;
}

// ---------------------------------------------------------------------------
// Street / shop helpers
// ---------------------------------------------------------------------------

function advanceStreet(): void {
  const board = currentBoard();
  if (!board) return;
  if (state.meta.temp_family.length > 0) {
    state.meta.family = state.meta.family.filter((f: any) => !f.temp);
    state.meta.temp_family = [];
    logEvent("Temporary family removed at street end.");
  }
  state.meta.side_effects.hand_size_bonus = 0;
  state.meta.side_effects.tea = false;
  state.meta.side_effects.coconut = false;
  state.meta.side_effects.hot_cocoa = false;
  state.meta.side_effects.sunscreen = false;
  state.meta.side_effects.seaweed_wrap = false;
  state.meta.side_effects.cloud_candy = false;
  state.meta.side_effects.mushroom = false;
  state.meta.side_effects.kelp_chips = false;
  state.meta.side_effects.freeze_dried_meal = false;
  state.meta.side_effects.oxygen_tank = false;
  state.meta.side_effects.raw_meat = false;
  state.meta.side_effects.sake = false;
  state.meta.side_effects.mochi = false;
  if (state.meta.street >= board.streets.length) {
    state.meta.street = 1;
  } else {
    state.meta.street += 1;
  }
}

function enterStreetPreview(): void {
  const board = currentBoard();
  const street = currentStreet();
  const next = nextStreet();
  state.preview = { board, street, next };
  state.phase = "street_preview";
  state.message = "Street preview. Press Enter to begin. M for map.";
}

function shouldOpenShop(): boolean {
  const board = currentBoard();
  const street = currentStreet();
  if (!board || !street) return false;
  if (street.id >= 10) return false;
  if (state.meta.board_id === "Mars") {
    return street.id === 3 || street.id === 6 || street.id === 9;
  }
  return true;
}

function startShop(): void {
  const [familyStock, dishStock] = buildShopStock();
  const board_id = state.meta.board_id;
  const specialRate = (data as any).special_cards.shop_rates[board_id] || 0.1;
  let specialOffer: any = null;
  if (Math.random() <= specialRate) {
    const pool = (data as any).special_cards.shop_pool;
    const specialId = pool[Math.floor(Math.random() * pool.length)];
    specialOffer = (data as any).special_cards.by_id(specialId);
  }
  state.shop = {
    family_stock: familyStock,
    dish_stock: dishStock,
    special_offer: specialOffer,
    family_reroll_cost: 1,
    dish_reroll_cost: 1,
    message: "Press Enter to open shop.",
    state: "intro",
    enhancement_page: 1,
    selected_enhancement: null,
    enhancement_message: null,
  };
  state.phase = "shop";
}

// ---------------------------------------------------------------------------
// Cut animation
// ---------------------------------------------------------------------------

function startCut(): void {
  const [target_x, target_y] = (ui as any).starter_position();
  state.cut = {
    visual_size: 52,
    deck_size: (state.deck || []).length,
    pointer: 1,
    direction: 1,
    velocity: 10,
    acceleration: 12,
    status: "aim",
    timer: 0,
    selected: null,
    card: null,
    drop_offset: 0,
    fade_left: 1,
    fade_right: 1,
    slide_progress: 0,
    target_x,
    target_y,
  };
  state.phase = "cut";
  state.message = "Stop the cursor (Enter) to cut.";
  logEvent("Cut phase started.");
}

function selectCutCard(): void {
  let ratio = 0;
  if (state.cut.visual_size > 1) {
    ratio = (state.cut.selected - 1) / (state.cut.visual_size - 1);
  }
  const deck = state.deck!;
  let deckIndex = deck.length - 1 - Math.floor(ratio * (deck.length - 1));
  if (deckIndex < 0) deckIndex = 0;
  if (deckIndex >= deck.length) deckIndex = deck.length - 1;
  state.cut.card = deck.splice(deckIndex, 1)[0];
  state.starter = state.cut.card;
  applyCurrentToCard(state.starter);
  logEvent("Cut card: " + (cards as any).card_label(state.starter) + ".");
}

function finalizeCut(): void {
  if (state.starter && state.starter.rank === 11) {
    awardPoints(state.dealer, 2, "His heels");
  }
  startPegging();
}

// ---------------------------------------------------------------------------
// Pegging
// ---------------------------------------------------------------------------

startPegging = function (): void {
  state.phase = "pegging";
  state.peg = {
    count: 0,
    stack: [],
    last_player: null,
    player_passed: false,
    ai_passed: false,
  };
  state.pending_pass_key = null;
  state.player_peg_hand = copyList(state.player_hand!);
  state.ai_peg_hand = copyList(state.ai_hand!);
  if (state.dealer === "player") {
    state.turn = "ai";
  } else {
    state.turn = "player";
  }
  state.message = "Pegging: play cards with 1-4, or press G to pass.";
  logEvent("Pegging started. Turn: " + state.turn + ".");
};

awardPoints = function (target: string, points: number, reason: string): void {
  if (points <= 0) return;
  if (target === "player") {
    state.player_score += points;
  } else {
    state.ai_score += points;
  }
  state.last_score_event = reason + " +" + String(points);
};

function applyGoIfNeeded(): void {
  const peg = state.peg!;
  if (peg.player_passed && peg.ai_passed) {
    if (peg.count !== 31 && peg.last_player) {
      awardPoints(peg.last_player, 1, "Go");
    }
    peg.count = 0;
    peg.stack = [];
    peg.player_passed = false;
    peg.ai_passed = false;
    if (peg.last_player) {
      state.turn = peg.last_player;
    }
    peg.last_player = null;
  }
}

function playCard(player: string, index: number): void {
  // index is 1-based
  const peg = state.peg!;
  const hand = player === "player" ? state.player_peg_hand! : state.ai_peg_hand!;
  const card = hand.splice(index - 1, 1)[0];
  const points = (scoring as any).pegging_points_for_play(peg.stack, card, peg.count);
  peg.count += (cards as any).card_value(card);
  peg.stack.push(card);
  peg.last_player = player;

  if (player === "player") {
    peg.player_passed = false;
  } else {
    peg.ai_passed = false;
  }

  if (points > 0) {
    awardPoints(player, points, "Peg");
  }
  if (player === "player") {
    state.pending_pass_key = null;
  }

  if (peg.count === 31) {
    peg.count = 0;
    peg.stack = [];
    peg.player_passed = false;
    peg.ai_passed = false;
    state.turn = player;
    return;
  }

  state.turn = player === "player" ? "ai" : "player";
  logEvent(player + " played " + (cards as any).card_label(card) + " (count " + peg.count + ").");
}

function canPlayAny(hand: any[], count: number): boolean {
  for (const card of hand) {
    if (!card.vined && (cards as any).card_value(card) + count <= 31) {
      return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// Show / scoring
// ---------------------------------------------------------------------------

function buildComboEntries(details: any): any[] {
  const entries: any[] = [];
  if (details && details.fifteens) {
    for (const f of details.fifteens) {
      entries.push({ label: "15 for " + f.points, cards: f.cards });
    }
  }
  if (details && details.pairs) {
    for (const p of details.pairs) {
      entries.push({ label: "Pair for " + p.points, cards: p.cards });
    }
  }
  if (details && details.runs) {
    for (const r of details.runs) {
      entries.push({ label: r.label + " for " + r.points, cards: r.cards });
    }
  }
  if (details && details.flush) {
    entries.push({
      label: details.flush.label + " for " + details.flush.points,
      cards: details.flush.cards,
    });
  }
  if (details && details.knobs) {
    entries.push({
      label: details.knobs.label + " for " + details.knobs.points,
      cards: details.knobs.cards,
    });
  }
  if (entries.length === 0) {
    entries.push({ label: "No score" });
  }
  return entries;
}

function scoreShow(): void {
  let [playerPoints, playerBreakdown, playerDetails] = (scoring as any).score_hand(
    state.player_show_hand,
    state.starter,
    false
  );
  let [aiPoints, aiBreakdown, aiDetails] = (scoring as any).score_hand(
    state.ai_show_hand,
    state.starter,
    false
  );
  let [cribPoints, cribBreakdown, cribDetails] = (scoring as any).score_hand(
    state.crib,
    state.starter,
    true
  );

  if (
    state.meta.side_effects.remove_crib_card &&
    state.dealer === "ai" &&
    state.crib!.length > 0
  ) {
    const index = Math.floor(Math.random() * state.crib!.length);
    const removed = state.crib!.splice(index, 1)[0];
    logEvent("Lemonade removed crib card " + (cards as any).card_label(removed) + ".");
    state.meta.side_effects.remove_crib_card = false;
    [cribPoints, cribBreakdown, cribDetails] = (scoring as any).score_hand(
      state.crib,
      state.starter,
      true
    );
  }

  if (state.meta.side_effects.fifteens_bonus > 0 && playerDetails && playerDetails.fifteens) {
    const extra = playerDetails.fifteens.length * state.meta.side_effects.fifteens_bonus;
    if (extra > 0) {
      playerPoints += extra;
      playerBreakdown.push("Cookies: +" + extra);
    }
    state.meta.side_effects.fifteens_bonus = 0;
  }

  if (state.meta.side_effects.pairs_bonus > 0 && playerDetails && playerDetails.pairs) {
    const extra = playerDetails.pairs.length * state.meta.side_effects.pairs_bonus;
    if (extra > 0) {
      playerPoints += extra;
      playerBreakdown.push("Nachos: +" + extra);
    }
    state.meta.side_effects.pairs_bonus = 0;
  }

  if (state.meta.side_effects.runs_bonus > 0 && playerDetails && playerDetails.runs) {
    let extra = 0;
    for (const run of playerDetails.runs) {
      extra += run.points * state.meta.side_effects.runs_bonus;
    }
    if (extra > 0) {
      playerPoints += extra;
      playerBreakdown.push("Wings: +" + extra);
    }
    state.meta.side_effects.runs_bonus = 0;
  }

  if (state.meta.side_effects.raw_meat && playerDetails) {
    let extra = 0;
    const addIfPrehistoric = (entry: any) => {
      if (!entry || !entry.cards) return;
      for (const c of entry.cards) {
        if (isPrehistoric(c)) {
          extra += entry.points * 2;
          return;
        }
      }
    };
    if (playerDetails.fifteens) {
      for (const f of playerDetails.fifteens) addIfPrehistoric(f);
    }
    if (playerDetails.pairs) {
      for (const p of playerDetails.pairs) addIfPrehistoric(p);
    }
    if (playerDetails.runs) {
      for (const r of playerDetails.runs) addIfPrehistoric(r);
    }
    if (playerDetails.flush) addIfPrehistoric(playerDetails.flush);
    if (playerDetails.knobs) addIfPrehistoric(playerDetails.knobs);
    if (extra > 0) {
      playerPoints += extra;
      playerBreakdown.push("Raw Meat: +" + extra);
    }
    state.meta.side_effects.raw_meat = false;
  }

  if (state.meta.board_id === "Japan" && playerDetails) {
    let kataBonus = 0;
    if (playerDetails.runs) {
      for (const run of playerDetails.runs) {
        if (run.points >= 5) {
          kataBonus += 10;
          break;
        }
      }
    }
    if (playerDetails.flush) {
      kataBonus += 10;
    }
    if (kataBonus > 0) {
      playerPoints += kataBonus;
      playerBreakdown.push("Kata: +" + kataBonus);
      if (state.meta.side_effects.mochi) {
        state.meta.money += 3;
        playerBreakdown.push("Mochi: +$3");
      }
    }
    state.meta.side_effects.mochi = false;
    state.meta.side_effects.sake = false;
  }

  if (state.meta.side_effects.next_score_multiplier > 1) {
    playerPoints *= state.meta.side_effects.next_score_multiplier;
    playerBreakdown.push("Moonshine: x" + state.meta.side_effects.next_score_multiplier);
    state.meta.side_effects.next_score_multiplier = 1;
    if (state.meta.side_effects.moonshine_active && state.meta.family.length > 0) {
      const removed = state.meta.family.pop();
      logEvent("Moonshine removed " + removed.name + ".");
    }
    state.meta.side_effects.moonshine_active = false;
  }

  if (state.dealer === "player") {
    awardPoints("player", playerPoints, "Hand");
    awardPoints("ai", aiPoints, "Hand");
    awardPoints("player", cribPoints, "Crib");
  } else {
    awardPoints("ai", aiPoints, "Hand");
    awardPoints("player", playerPoints, "Hand");
    awardPoints("ai", cribPoints, "Crib");
  }

  state.show_details = {
    player: { total: playerPoints, breakdown: playerBreakdown, details: playerDetails },
    ai: { total: aiPoints, breakdown: aiBreakdown, details: aiDetails },
    crib: {
      total: cribPoints,
      breakdown: cribBreakdown,
      owner: state.dealer === "player" ? "yours" : "opponent",
      details: cribDetails,
    },
  };
  logEvent(
    "Show scoring: player " +
      playerPoints +
      ", opponent " +
      aiPoints +
      ", crib " +
      cribPoints +
      "."
  );
}

function advanceShowPhase(): void {
  if (state.phase === "show_ai") {
    state.phase = "show_crib";
    state.message = "Show: crib (" + state.show_details.crib.owner + "). Press Enter.";
  } else if (state.phase === "show_crib") {
    state.phase = "show_player";
    state.message = "Show: your hand. Press Enter.";
  } else if (state.phase === "show_player") {
    state.phase = "show_summary";
    state.message = "Summary. Press Enter.";
  } else if (state.phase === "show_summary") {
    markStreetComplete();
    if (state.player_score >= GOAL_SCORE) {
      state.level += 1;
      state.player_score = 0;
      state.ai_score = 0;
      state.dealer = toggleDealer(state.dealer);
      startRound();
      return;
    }
    if (state.ai_score >= GOAL_SCORE) {
      state.phase = "run_end";
      state.message = "Game over. Press R to restart.";
      writeHistory();
      return;
    }
    if (shouldOpenShop()) {
      startShop();
      return;
    }
    state.dealer = toggleDealer(state.dealer);
    advanceStreet();
    enterStreetPreview();
  }
}

function checkPeggingEnd(): void {
  if ((state.player_peg_hand || []).length === 0 && (state.ai_peg_hand || []).length === 0) {
    scoreShow();
    state.phase = "show_ai";
    state.message = "Show: opponent hand. Press Enter.";
    state.meta.side_effects.show_ai_hand = false;
  }
}

// ---------------------------------------------------------------------------
// Start round
// ---------------------------------------------------------------------------

function startRound(): void {
  let deck: any[] = (cards as any).shuffle(
    (cards as any).build_deck({
      board_id: state.meta.board_id,
      deck_counts: state.meta.deck_counts,
      enhancements: state.meta.enhancements,
    })
  );
  let playerHand: any[] = [];
  const aiHand: any[] = [];
  const drawBonus = state.meta.side_effects.draw_bonus || 0;
  const handBonus = state.meta.side_effects.hand_size_bonus || 0;
  const playerDraws = 6 + drawBonus + handBonus;

  for (let i = 0; i < playerDraws; i++) {
    playerHand.push(deck.pop());
  }
  for (let i = 0; i < 6; i++) {
    aiHand.push(deck.pop());
  }

  const board_id = state.meta.board_id;
  const street = currentStreet();

  if (board_id === "Space") {
    processOrbitReturns();
  }

  if (board_id === "Aquatic" && street) {
    let map: Record<string, string> | null = null;
    if (street.id === 2) {
      map = { H: "S" };
    } else if (street.id === 4) {
      map = { D: "C" };
    } else if (street.id === 7 || street.id === 10) {
      const options = [{ H: "S" }, { D: "C" }, { S: "H" }, { C: "D" }];
      map = options[Math.floor(Math.random() * options.length)];
    }
    if (state.meta.side_effects.kelp_chips) {
      map = null;
      state.meta.side_effects.kelp_chips = false;
      logEvent("Kelp Chips: currents ignored.");
    }
    state.meta.side_effects.current_map = map;
    if (map) {
      for (const card of playerHand) applyCurrentToCard(card);
      for (const card of aiHand) applyCurrentToCard(card);
      logEvent("Current active.");
    }
  } else {
    state.meta.side_effects.current_map = null;
  }

  if (board_id === "Cavedwellers" && street) {
    let visible: number | null = null;
    if (street.id === 2) visible = 4;
    else if (street.id === 3) visible = 3;
    else if (street.id === 5) visible = 2;
    else if (street.id === 6) visible = 3;
    else if (street.id === 7) visible = 2;
    else if (street.id === 9) visible = 1;
    else if (street.id === 10) visible = 0;
    applyVisibility(playerHand, visible);
    logEvent(
      "Darkness visibility: " +
        (visible !== null ? String(visible) : String(playerHand.length)) +
        " cards."
    );
  }

  if (board_id === "Jungle" && street) {
    let vineCount = 0;
    if (street.id === 2) vineCount = 1;
    else if (street.id === 7) vineCount = 2;
    if (vineCount > 0) {
      if (state.meta.side_effects.coconut) {
        logEvent("Coconut freed vined cards this hand.");
        state.meta.side_effects.coconut = false;
      } else {
        const indices: number[] = playerHand.map((_, i) => i);
        const toVine = Math.min(vineCount, indices.length);
        for (let k = 0; k < toVine; k++) {
          const pick = Math.floor(Math.random() * indices.length);
          const index = indices.splice(pick, 1)[0];
          playerHand[index].vined = true;
        }
        logEvent("Vined " + vineCount + " cards this hand.");
      }
    }
  }

  if (board_id === "Beach" && street) {
    let threshold = 0;
    let washCount = 0;
    if (street.id === 1) threshold = 0;
    else if (street.id === 2) { threshold = 1; washCount = 1; }
    else if (street.id === 3) threshold = 2;
    else if (street.id === 4) threshold = 2;
    else if (street.id === 5) { threshold = 3; washCount = 1; }
    else if (street.id === 6) { threshold = 3; washCount = 1; }
    else if (street.id === 7) { threshold = 4; washCount = 1; }
    else if (street.id === 8) threshold = 4;
    else if (street.id === 9) threshold = 5;
    else if (street.id === 10) { threshold = 6; washCount = 1; }

    if (threshold > 0) {
      let roll = randomIntRange(1, 6);
      if (state.meta.side_effects.sunscreen) {
        roll = Math.min(6, roll + 2);
        state.meta.side_effects.sunscreen = false;
      }
      if (roll <= threshold) {
        state.meta.side_effects.flooded = true;
        logEvent("Flooded (roll " + roll + ").");
        if (washCount > 0 && playerHand.length > 0) {
          const washed: any[] = [];
          for (let k = 0; k < Math.min(washCount, playerHand.length); k++) {
            const index = Math.floor(Math.random() * playerHand.length);
            washed.push(playerHand.splice(index, 1)[0]);
          }
          if (state.meta.side_effects.seaweed_wrap) {
            for (const c of washed) playerHand.push(c);
            logEvent("Seaweed Wrap returned washed cards.");
            state.meta.side_effects.seaweed_wrap = false;
          } else if (street.id === 7) {
            for (const c of washed) {
              removeCardId((cards as any).card_id(c), 1);
            }
            logEvent("Washed cards did not return.");
          } else {
            logEvent("Washed away " + washed.length + " cards.");
          }
        }
      } else {
        state.meta.side_effects.flooded = false;
      }
    }
  }

  if (board_id === "Space" && street) {
    let orbitCount = 0;
    let orbitTurns = 2;
    let destroyCount = 0;
    if (street.id === 2) orbitCount = 1;
    else if (street.id === 4) orbitCount = 2;
    else if (street.id === 8) destroyCount = 1;
    else if (street.id === 9) orbitCount = 3;
    else if (street.id === 10) { orbitCount = Math.min(3, playerHand.length); orbitTurns = 3; }

    if (orbitCount > 0 && playerHand.length > 0) {
      const indices: number[] = playerHand.map((_, i) => i);
      const toOrbit = Math.min(orbitCount, indices.length);
      for (let k = 0; k < toOrbit; k++) {
        const pick = Math.floor(Math.random() * indices.length);
        const index = indices.splice(pick, 1)[0];
        const card = playerHand.splice(index, 1)[0];
        const id = (cards as any).card_id(card);
        if (state.meta.side_effects.freeze_dried_meal) {
          playerHand.push(card);
        } else {
          removeCardId(id, 1);
          enqueueOrbit(id, orbitTurns);
        }
      }
      if (state.meta.side_effects.freeze_dried_meal) {
        state.meta.side_effects.freeze_dried_meal = false;
        logEvent("Freeze-Dried Meal returned orbit card immediately.");
      } else {
        logEvent("Orbiting " + toOrbit + " cards.");
      }
      for (let k = 0; k < toOrbit; k++) {
        if (deck.length > 0) playerHand.push(deck.pop());
      }
    }

    if (destroyCount > 0 && playerHand.length > 0) {
      for (let k = 0; k < destroyCount; k++) {
        const index = Math.floor(Math.random() * playerHand.length);
        const card = playerHand.splice(index, 1)[0];
        removeCardId((cards as any).card_id(card), 1);
        logEvent("Asteroid Belt destroyed " + (cards as any).card_label(card) + ".");
      }
    }
  }

  if (board_id === "Mars" && street) {
    const roll = randomIntRange(1, 6);
    let hit = false;
    if (street.id === 2 && roll === 6) hit = true;
    else if (street.id === 9 && roll >= 5) hit = true;
    if (state.meta.side_effects.oxygen_tank) {
      hit = true;
      state.meta.side_effects.oxygen_tank = false;
    }
    if (hit) {
      const dish = pickSideDish();
      if (dish && state.meta.side_pouch.length < state.meta.side_pouch_capacity) {
        state.meta.side_pouch.push(dish);
        logEvent("Supply drop: " + dish.name + ".");
      } else {
        logEvent("Supply drop triggered but pouch full.");
      }
    }
  }

  if (state.meta.side_effects.redraw_next_hand) {
    for (const c of playerHand) deck.push(c);
    playerHand = [];
    deck = (cards as any).shuffle(deck);
    for (let i = 0; i < playerDraws; i++) {
      playerHand.push(deck.pop());
    }
    state.meta.side_effects.redraw_next_hand = false;
    logEvent("Joint redraw applied.");
  }

  state.meta.side_effects.draw_bonus = 0;
  if (state.meta.side_effects.peek_cut) {
    if (deck.length > 0) {
      state.peek_cut_card_label = (cards as any).card_label(deck[deck.length - 1]);
      state.message = "Peek cut: " + state.peek_cut_card_label;
    }
    state.meta.side_effects.peek_cut = false;
  } else {
    state.peek_cut_card_label = null;
  }

  state.round = (state.round || 0) + 1;
  state.deck = deck;
  state.player_hand = playerHand;
  state.ai_hand = aiHand;
  state.player_show_hand = copyList(playerHand);
  state.ai_show_hand = copyList(aiHand);
  state.crib = [];
  state.starter = null;
  state.discard_selection = {};
  state.phase = "discard";
  if (state.dealer === "player") {
    state.message = "Your crib. Discard 2 cards (1-6), then Enter.";
  } else {
    state.message = "Opponent's crib. Discard 2 cards (1-6), then Enter.";
  }

  const handicap = Math.max(0, state.level - 1);
  if (handicap > 0) {
    state.ai_score += handicap;
    state.message += " AI gets +" + handicap + " handicap.";
  }
  logEvent("Start hand. Dealer: " + state.dealer + ".");
}

// ---------------------------------------------------------------------------
// New run
// ---------------------------------------------------------------------------

function startNewRun(): void {
  state = {
    phase: "title",
    level: 1,
    player_score: 0,
    ai_score: 0,
    dealer: "player",
    message: "Press Enter to start.",
    last_score_event: "",
    round: 0,
    history: [],
    history_written: false,
    meta: {
      board_id: "Backyard",
      street: 1,
      money: 5,
      family_slots: (data as any).boards.family_slots.start,
      family: [],
      side_pouch: [],
      side_pouch_capacity: 3,
      completed_streets: {},
      deck_counts: (cards as any).default_counts("Backyard"),
      enhancements: {},
      special_pouch: [],
      special_pouch_capacity: 2,
      graveyard: [],
      side_effects: {
        draw_bonus: 0,
        redraw_next_hand: false,
        fifteens_bonus: 0,
        pairs_bonus: 0,
        runs_bonus: 0,
        remove_crib_card: false,
        hand_size_bonus: 0,
        extra_shop_action: 0,
        next_score_multiplier: 1,
        moonshine_active: false,
        peek_cut: false,
        pretzels: false,
        show_ai_hand: false,
        flooded: false,
        current_map: null,
        tea: false,
        coconut: false,
        hot_cocoa: false,
        sunscreen: false,
        seaweed_wrap: false,
        cloud_candy: false,
        mushroom: false,
        kelp_chips: false,
        freeze_dried_meal: false,
        oxygen_tank: false,
        raw_meat: false,
        sake: false,
        mochi: false,
      },
      temp_family: [],
      orbit_queue: [],
    },
  };
  logEvent("New run started.");
}

// ---------------------------------------------------------------------------
// Internal draw (non-Balatro path)
// ---------------------------------------------------------------------------

function internalDraw(ctx: CanvasRenderingContext2D): void {
  (ui as any).draw_scoreboard(ctx, state);
  (ui as any).draw_phase(ctx, state.phase, 30, 130);
  (ui as any).draw_text_block(ctx, [state.message || ""], 30, 160);
  if (state.last_score_event && state.last_score_event !== "") {
    (ui as any).draw_text_block(ctx, ["Last: " + state.last_score_event], 30, 190);
  }

  const board = currentBoard();
  const street = currentStreet();
  const next = nextStreet();
  if (board && street) {
    const lines = [
      "Board: " + board.name + " (" + board.subtitle + ")",
      "Street " + String(street.id) + ": " + street.name,
      "Condition: " + street.condition,
      "Objective: " + street.objective,
      "Money: $" + String(state.meta.money),
      "Family slots: " + String(state.meta.family_slots),
      "I: inventory  D: deck  U: eat side dish",
    ];
    if (state.meta.side_effects.flooded) {
      lines.push("Flooded!");
    }
    if (next) {
      lines.push("Next: " + String(next.id) + " - " + next.name);
      lines.push("Next condition: " + next.condition);
      lines.push("Next objective: " + next.objective);
    }
    (ui as any).draw_text_block(ctx, lines, 520, 20);
  }

  if (state.phase === "discard") {
    ctx.fillText("Your hand:", 30, 240 + 14);
    (ui as any).draw_hand(ctx, state.player_hand, 30, 270, state.discard_selection);
    if (state.discard_overlimit_at != null) {
      const age = performance.now() / 1000 - state.discard_overlimit_at;
      if (age < 0.6) {
        setColor(ctx, 0.6, 0.6, 0.6, 0.5);
        const [card_w, card_h, gap] = (ui as any).card_dimensions();
        const x = 30;
        const y = 270;
        fillRoundedRect(
          ctx,
          x - 6,
          y - 6,
          (card_w + gap) * (state.player_hand || []).length - gap + 12,
          card_h + 12,
          6
        );
        setColor(ctx, 1, 1, 1, 1);
      } else {
        state.discard_overlimit_at = null;
      }
    }
  } else if (state.phase === "cut") {
    ctx.fillText("Cut the deck:", 30, 240 + 14);
    (ui as any).draw_cut_stack(ctx, state.cut, 30, 270);
  } else if (state.phase === "pegging") {
    ctx.fillText("Peg count: " + String(state.peg!.count), 30, 230 + 14);
    ctx.fillText("Peg turn: " + state.turn, 30, 250 + 14);
    ctx.fillText("Your peg hand:", 30, 280 + 14);
    (ui as any).draw_hand(ctx, state.player_peg_hand, 30, 310);
    if (state.meta.side_effects.show_ai_hand) {
      ctx.fillText("Opponent peg hand:", 30, 460 + 14);
      (ui as any).draw_hand(ctx, state.ai_peg_hand, 30, 490);
    }
    if (state.starter) {
      const [starter_x, starter_y] = (ui as any).starter_position();
      ctx.fillText("Cut card", starter_x, starter_y - 20 + 14);
      (ui as any).draw_face_up_card(ctx, state.starter, starter_x, starter_y);
    }
    if (state.turn === "player" && !canPlayAny(state.player_peg_hand!, state.peg!.count)) {
      ctx.fillText("PASS available (G/Enter).", 30, 620 + 14);
    }
  } else if (state.phase === "show_ai") {
    ctx.fillText("Opponent show hand:", 30, 240 + 14);
    (ui as any).draw_cards_row(ctx, appendCard(state.ai_show_hand!, state.starter), 30, 270);
    if (state.show_details && state.show_details.ai) {
      const entries = buildComboEntries(state.show_details.ai.details);
      entries.push({ label: "Total: " + String(state.show_details.ai.total) });
      (ui as any).draw_combo_entries(ctx, entries, 30, 420);
    }
  } else if (state.phase === "show_crib") {
    const cribOwner =
      state.show_details && state.show_details.crib && state.show_details.crib.owner
        ? state.show_details.crib.owner
        : "?";
    ctx.fillText("Crib (" + cribOwner + "):", 30, 240 + 14);
    (ui as any).draw_cards_row(ctx, appendCard(state.crib!, state.starter), 30, 270);
    if (state.show_details && state.show_details.crib) {
      const entries = buildComboEntries(state.show_details.crib.details);
      entries.push({ label: "Total: " + String(state.show_details.crib.total) });
      (ui as any).draw_combo_entries(ctx, entries, 30, 420);
    }
  } else if (state.phase === "show_player") {
    ctx.fillText("Your show hand:", 30, 240 + 14);
    (ui as any).draw_cards_row(ctx, appendCard(state.player_show_hand!, state.starter), 30, 270);
    if (state.show_details && state.show_details.player) {
      const entries = buildComboEntries(state.show_details.player.details);
      entries.push({ label: "Total: " + String(state.show_details.player.total) });
      (ui as any).draw_combo_entries(ctx, entries, 30, 420);
    }
  } else if (state.phase === "show_summary") {
    if (state.show_details && state.show_details.player) {
      (ui as any).draw_text_block(
        ctx,
        [
          "Player total: " + String(state.show_details.player.total),
          "Opponent total: " + String(state.show_details.ai.total),
          "Crib (" +
            state.show_details.crib.owner +
            ") total: " +
            String(state.show_details.crib.total),
        ],
        30,
        240
      );
    }
  } else if (state.phase === "street_preview") {
    const preview = state.preview;
    if (preview && preview.board && preview.street) {
      ctx.fillText("ENTERING: " + preview.street.name, 30, 240 + 14);
      ctx.fillText(
        "Street " + String(preview.street.id) + " of " + String(preview.board.streets.length),
        30,
        265 + 14
      );
      (ui as any).draw_text_block(
        ctx,
        [
          "Board: " + preview.board.name + " (" + preview.board.subtitle + ")",
          "Condition: " + preview.street.condition,
          "Objective: " + preview.street.objective,
        ],
        30,
        300
      );
      if (preview.next) {
        (ui as any).draw_text_block(
          ctx,
          [
            "Next: " + String(preview.next.id) + " - " + preview.next.name,
            "Next condition: " + preview.next.condition,
            "Next objective: " + preview.next.objective,
          ],
          30,
          400
        );
      }
      ctx.fillText("Press Enter to begin. M for board map. U to eat dish.", 30, 520 + 14);
    }
  } else if (state.phase === "special_use") {
    const special = state.meta.special_pouch[(state.special_use.special_index || 1) - 1];
    ctx.fillText("Use Special Card: " + special.name, 30, 240 + 14);
    const suDeck = currentDeckForView();
    const suPerPage = 9;
    const [suPageItems] = deckPage(suDeck, state.special_use.page, suPerPage);
    for (let i = 0; i < suPageItems.length; i++) {
      const card = suPageItems[i];
      let label = (cards as any).card_label(card);
      if (card.enhancement) label += " [" + card.enhancement + "]";
      ctx.fillText(String(i + 1) + ") " + label, 30, 265 + i * 18 + 14);
    }
    ctx.fillText("Page " + String(state.special_use.page) + "  (N/P)", 30, 440 + 14);
    ctx.fillText("Press B to cancel.", 30, 460 + 14);
    if (state.special_use.message) {
      ctx.fillText(state.special_use.message, 30, 490 + 14);
    }
  } else if (state.phase === "side_dish_use") {
    const dish = state.side_dish_use.dish;
    ctx.fillText("Eat Side Dish: " + dish.name, 30, 240 + 14);
    const sduDeck = currentDeckForView();
    const sduPerPage = 9;
    const [sduPageItems] = deckPage(sduDeck, state.side_dish_use.page, sduPerPage);
    for (let i = 0; i < sduPageItems.length; i++) {
      const card = sduPageItems[i];
      let label = (cards as any).card_label(card);
      if (card.enhancement) label += " [" + card.enhancement + "]";
      ctx.fillText(String(i + 1) + ") " + label, 30, 265 + i * 18 + 14);
    }
    ctx.fillText("Page " + String(state.side_dish_use.page) + "  (N/P)", 30, 440 + 14);
    ctx.fillText("Press B to cancel.", 30, 460 + 14);
    if (state.side_dish_use.message) {
      ctx.fillText(state.side_dish_use.message, 30, 490 + 14);
    }
  } else if (state.phase === "inventory") {
    ctx.fillText("Inventory", 30, 240 + 14);
    ctx.fillText(
      "Aunties/Uncles (" +
        String(state.meta.family.length) +
        "/" +
        String(state.meta.family_slots) +
        ")",
      30,
      270 + 14
    );
    for (let i = 0; i < state.meta.family.length; i++) {
      const item = state.meta.family[i];
      ctx.fillText("- " + item.name + ": " + item.effect, 30, 295 + i * 18 + 14);
    }
    const dishesY = 295 + state.meta.family.length * 18 + 18;
    ctx.fillText(
      "Side Dishes (" +
        String(state.meta.side_pouch.length) +
        "/" +
        String(state.meta.side_pouch_capacity) +
        ")",
      30,
      dishesY + 14
    );
    for (let i = 0; i < state.meta.side_pouch.length; i++) {
      const item = state.meta.side_pouch[i];
      ctx.fillText("- " + item.name + " - " + item.effect, 30, dishesY + 25 + i * 18 + 14);
    }
    const specialsY = dishesY + 25 + state.meta.side_pouch.length * 18 + 18;
    ctx.fillText(
      "Special Cards (" +
        String(state.meta.special_pouch.length) +
        "/" +
        String(state.meta.special_pouch_capacity) +
        ")",
      30,
      specialsY + 14
    );
    for (let i = 0; i < state.meta.special_pouch.length; i++) {
      const item = state.meta.special_pouch[i];
      ctx.fillText(
        String(i + 1) + ") " + item.name + " - " + item.effect,
        30,
        specialsY + 25 + i * 18 + 14
      );
    }
    ctx.fillText(
      "Press number to use Special. D to view deck. U to eat dish. B to return.",
      30,
      specialsY + 25 + state.meta.special_pouch.length * 18 + 18 + 14
    );
  } else if (state.phase === "deck_view") {
    ctx.fillText("Deck Viewer", 30, 240 + 14);
    const dvEntries = deckEntries();
    const dvPerPage = 9;
    const [dvPageItems] = listPage(dvEntries, state.deck_view_page || 1, dvPerPage);
    for (let i = 0; i < dvPageItems.length; i++) {
      const entry = dvPageItems[i];
      let line = String(i + 1) + ") " + entry.label + " x" + String(entry.count);
      if (entry.enhancement) line += " [" + entry.enhancement + "]";
      ctx.fillText(line, 30, 265 + i * 18 + 14);
    }
    ctx.fillText(
      "Page " + String(state.deck_view_page || 1) + "  (N/P)",
      30,
      440 + 14
    );
    ctx.fillText("Press B to return.", 30, 460 + 14);
  } else if (state.phase === "board_map") {
    const bmBoard = currentBoard();
    if (bmBoard) {
      ctx.fillText(bmBoard.name + " (" + bmBoard.subtitle + ")", 30, 240 + 14);
      const completed = state.meta.completed_streets[state.meta.board_id] || {};
      let y = 270;
      for (let i = 0; i < bmBoard.streets.length; i++) {
        const bmStreet = bmBoard.streets[i];
        let marker = "○";
        if (bmStreet.id === state.meta.street) marker = "►";
        else if ((completed as any)[bmStreet.id]) marker = "✓";
        ctx.fillText(
          marker + " Street " + String(bmStreet.id) + ": " + bmStreet.name,
          30,
          y + 14
        );
        ctx.fillText("  Condition: " + bmStreet.condition, 30, y + 16 + 14);
        ctx.fillText("  Objective: " + bmStreet.objective, 30, y + 32 + 14);
        y += 56;
      }
      ctx.fillText("Press M or Enter to return.", 30, y + 10 + 14);
    }
  } else if (state.phase === "shop") {
    const shop = state.shop;
    ctx.fillText("AUNTIE EDNA'S ROADSIDE STAND", 30, 240 + 14);
    if (shop.state === "intro") {
      ctx.fillText("Press Enter to open the shop.", 30, 270 + 14);
      if (shop.message) ctx.fillText(shop.message, 30, 300 + 14);
      return;
    }
    if (shop.state === "enhance_select") {
      ctx.fillText("Card Enhancements", 30, 270 + 14);
      const esList = enhancementShopList();
      const esPerPage = 9;
      const [esPageItems] = listPage(esList, shop.enhancement_select_page || 1, esPerPage);
      for (let i = 0; i < esPageItems.length; i++) {
        const item = esPageItems[i];
        ctx.fillText(
          String(i + 1) + ") " + item.name + " $" + String(item.cost) + " - " + item.effect,
          30,
          295 + i * 18 + 14
        );
      }
      ctx.fillText(
        "Page " + String(shop.enhancement_select_page || 1) + "  (N/P)",
        30,
        470 + 14
      );
      ctx.fillText("Press B to return to shop.", 30, 520 + 14);
      if (shop.enhancement_message)
        ctx.fillText(shop.enhancement_message, 30, 550 + 14);
      return;
    }
    if (shop.state === "enhance_card") {
      const enhancement = shop.selected_enhancement;
      ctx.fillText(
        "Select card for " + enhancement.name + " ($" + String(enhancement.cost) + ")",
        30,
        270 + 14
      );
      const ecDeck = currentDeckForView();
      const ecPerPage = 9;
      const [ecPageItems] = deckPage(ecDeck, shop.enhancement_page, ecPerPage);
      for (let i = 0; i < ecPageItems.length; i++) {
        const card = ecPageItems[i];
        const id = (cards as any).card_id(card);
        let label = (cards as any).card_label(card);
        if (state.meta.enhancements[id]) label += " [" + state.meta.enhancements[id] + "]";
        ctx.fillText(String(i + 1) + ") " + label, 30, 295 + i * 18 + 14);
      }
      ctx.fillText("Page " + String(shop.enhancement_page) + "  (N/P)", 30, 480 + 14);
      ctx.fillText("Press B to go back.", 30, 500 + 14);
      if (shop.enhancement_message)
        ctx.fillText(shop.enhancement_message, 30, 530 + 14);
      return;
    }
    // active shop state
    ctx.fillText(
      "Family for Hire (Reroll $" + String(shop.family_reroll_cost) + ")",
      30,
      270 + 14
    );
    for (let i = 0; i < shop.family_stock.length; i++) {
      const item = shop.family_stock[i];
      ctx.fillText(
        String(i + 1) + ") " + item.name + " - " + item.effect + " ($" + String(item.cost) + ")",
        30,
        295 + i * 18 + 14
      );
    }
    ctx.fillText(
      "Side Dishes (Reroll $" + String(shop.dish_reroll_cost) + ")",
      30,
      420 + 14
    );
    for (let i = 0; i < shop.dish_stock.length; i++) {
      const item = shop.dish_stock[i];
      ctx.fillText(
        String(i + 6) + ") " + item.name + " - " + item.effect + " ($" + String(item.cost) + ")",
        30,
        445 + i * 18 + 14
      );
    }
    if (shop.special_offer) {
      const offer = shop.special_offer;
      const offerY = 470 + shop.dish_stock.length * 18 + 18;
      ctx.fillText(
        "Special Card: " + offer.name + " ($" + String(offer.cost) + ") [C to buy]",
        30,
        offerY + 14
      );
      ctx.fillText(offer.effect, 30, offerY + 18 + 14);
    }
    const comingY = 470 + shop.dish_stock.length * 18 + 54;
    ctx.fillText("Card Enhancements: press E", 30, comingY + 14);
    const ceList = (data as any).boards.shop_structure.card_enhancements;
    for (let i = 0; i < Math.min(3, ceList.length); i++) {
      const item = ceList[i];
      ctx.fillText(item.name + " $" + String(item.cost), 30, comingY + 25 + i * 18 + 14);
    }
    const familyPreviewY = comingY + 25 + ceList.length * 18 + 18;
    ctx.fillText("Coming soon family:", 30, familyPreviewY + 14);
    const csfList = (data as any).boards.shop_structure.coming_soon_family;
    for (let i = 0; i < csfList.length; i++) {
      ctx.fillText("- " + csfList[i].name, 30, familyPreviewY + 18 + i * 18 + 14);
    }
    const dishPreviewY = familyPreviewY + 18 + csfList.length * 18 + 18;
    ctx.fillText("Coming soon side dishes:", 30, dishPreviewY + 14);
    const csdList = (data as any).boards.shop_structure.coming_soon_dishes;
    for (let i = 0; i < csdList.length; i++) {
      ctx.fillText("- " + csdList[i].name, 30, dishPreviewY + 18 + i * 18 + 14);
    }

    ctx.fillText(
      "Your Family (" +
        String(state.meta.family.length) +
        "/" +
        String(state.meta.family_slots) +
        ")",
      560,
      270 + 14
    );
    for (let i = 0; i < state.meta.family.length; i++) {
      ctx.fillText("- " + state.meta.family[i].name, 560, 295 + i * 18 + 14);
    }
    ctx.fillText(
      "Side Dish Pouch (" +
        String(state.meta.side_pouch.length) +
        "/" +
        String(state.meta.side_pouch_capacity) +
        ")",
      560,
      420 + 14
    );
    for (let i = 0; i < state.meta.side_pouch.length; i++) {
      ctx.fillText("- " + state.meta.side_pouch[i].name, 560, 445 + i * 18 + 14);
    }
    ctx.fillText(
      "Special Pouch (" +
        String(state.meta.special_pouch.length) +
        "/" +
        String(state.meta.special_pouch_capacity) +
        ")",
      560,
      520 + 14
    );
    for (let i = 0; i < state.meta.special_pouch.length; i++) {
      ctx.fillText("- " + state.meta.special_pouch[i].name, 560, 545 + i * 18 + 14);
    }
    ctx.fillText("Press Enter to continue. U to eat dish.", 560, 570 + 14);
    if (shop.message) ctx.fillText(shop.message, 30, 720 + 14);
  } else if (state.phase === "eat_side_dish") {
    ctx.fillText("Eat Side Dish", 30, 240 + 14);
    ctx.fillText("Pick a dish to consume (number). B to cancel.", 30, 270 + 14);
    for (let i = 0; i < state.meta.side_pouch.length; i++) {
      const item = state.meta.side_pouch[i];
      ctx.fillText(
        String(i + 1) + ") " + item.name + " - " + item.effect,
        30,
        295 + i * 18 + 14
      );
    }
  } else if (state.phase === "run_end") {
    ctx.fillText("Final level: " + String(state.level), 30, 240 + 14);
  }
}

// ---------------------------------------------------------------------------
// Exported entry points
// ---------------------------------------------------------------------------

export function load(ctx: CanvasRenderingContext2D): void {
  if (USE_BALATRO_MODE) {
    (balatrMode as any).load(ctx);
    return;
  }
  // Set canvas/body background
  document.body.style.background = "rgb(31,31,41)";
  (ui as any).set_font(ctx);
  startNewRun();
}

export function update(dt: number): void {
  if (USE_BALATRO_MODE) {
    (balatrMode as any).update(dt);
    return;
  }
  if (state.phase === "cut") {
    if (state.cut.status === "aim") {
      state.cut.velocity += state.cut.acceleration * dt;
      state.cut.pointer += state.cut.velocity * state.cut.direction * dt;
      if (state.cut.pointer >= state.cut.visual_size) {
        state.cut.pointer = state.cut.visual_size;
        state.cut.direction = -1;
      } else if (state.cut.pointer <= 1) {
        state.cut.pointer = 1;
        state.cut.direction = 1;
      }
    } else {
      state.cut.timer += dt;
      if (state.cut.status === "clear_left") {
        state.cut.fade_left = Math.max(0, 1 - state.cut.timer / CUT_CLEAR_ABOVE);
        if (state.cut.timer >= CUT_CLEAR_ABOVE) {
          state.cut.status = "drop";
          state.cut.timer = 0;
        }
      } else if (state.cut.status === "drop") {
        const progress = Math.min(1, state.cut.timer / CUT_DROP);
        state.cut.drop_offset = progress * 140;
        if (state.cut.timer >= CUT_DROP) {
          state.cut.status = "reveal";
          state.cut.timer = 0;
        }
      } else if (state.cut.status === "reveal") {
        if (state.cut.timer >= CUT_REVEAL) {
          state.cut.status = "clear_right";
          state.cut.timer = 0;
        }
      } else if (state.cut.status === "clear_right") {
        state.cut.fade_right = Math.max(0, 1 - state.cut.timer / CUT_CLEAR_BELOW);
        if (state.cut.timer >= CUT_CLEAR_BELOW) {
          state.cut.status = "slide";
          state.cut.timer = 0;
          state.cut.slide_progress = 0;
        }
      } else if (state.cut.status === "slide") {
        state.cut.slide_progress = Math.min(1, state.cut.timer / CUT_SLIDE);
        if (state.cut.timer >= CUT_SLIDE) {
          finalizeCut();
        }
      }
    }
    return;
  }

  if (state.phase !== "pegging") return;
  if (state.turn !== "ai") return;

  const peg = state.peg!;
  const canPlay = canPlayAny(state.ai_peg_hand!, peg.count);
  if (!canPlay) {
    peg.ai_passed = true;
    state.turn = "player";
    applyGoIfNeeded();
    checkPeggingEnd();
    return;
  }

  const index = aiChoosePlay(state.ai_peg_hand!, peg.count, peg.stack);
  if (index !== null) {
    playCard("ai", index);
  }
  applyGoIfNeeded();
  checkPeggingEnd();
}

export function keypressed(key: string): void {
  if (USE_BALATRO_MODE) {
    (balatrMode as any).keypressed(key);
    return;
  }
  if (key === "escape") {
    // noop / window.close()
    return;
  }

  if (key === "d" && state.phase !== "deck_view") {
    state.view_prev = state.phase;
    state.deck_view_page = 1;
    state.phase = "deck_view";
    return;
  }

  if (key === "i" && state.phase !== "inventory") {
    state.view_prev = state.phase;
    state.phase = "inventory";
    return;
  }

  if (key === "u" && state.meta.side_pouch.length > 0) {
    state.view_prev = state.phase;
    state.phase = "eat_side_dish";
    return;
  }

  if (key === "h") {
    writeHistory();
    return;
  }

  if (state.phase === "title") {
    if (key === "return" || key === "space") {
      enterStreetPreview();
    }
    return;
  }

  if (state.phase === "discard") {
    const index = parseInt(key, 10);
    if (!isNaN(index) && index >= 1 && index <= (state.player_hand || []).length) {
      if (state.player_hand![index - 1].vined) {
        state.message = "That card is vined this hand.";
        return;
      }
      if ((state.discard_selection as any)[index]) {
        (state.discard_selection as any)[index] = false;
      } else {
        if (countSelected(state.discard_selection!) >= 2) {
          state.discard_overlimit_at = performance.now() / 1000;
        } else {
          (state.discard_selection as any)[index] = true;
        }
      }
    }
    if (key === "return") {
      if (countSelected(state.discard_selection!) === 2) {
        state.discard_overlimit_at = null;
        const indices: number[] = [];
        for (const [k, v] of Object.entries(state.discard_selection!)) {
          if (v) indices.push(Number(k));
        }
        const removed = removeIndices(state.player_hand!, indices);
        for (const c of removed) state.crib!.push(c);
        const removedLabels = removed.map((c: any) => (cards as any).card_label(c));
        logEvent("Player discarded: " + removedLabels.join(", ") + ".");

        const aiIndices = aiChooseDiscard(state.ai_hand!);
        const aiRemoved = removeIndices(state.ai_hand!, aiIndices);
        for (const c of aiRemoved) state.crib!.push(c);
        const aiLabels = aiRemoved.map((c: any) => (cards as any).card_label(c));
        logEvent("Opponent discarded: " + aiLabels.join(", ") + ".");

        if (
          state.meta.side_effects.pretzels &&
          state.player_hand!.length > 0 &&
          state.crib!.length > 0
        ) {
          const handIndex = Math.floor(Math.random() * state.player_hand!.length);
          const cribIndex = Math.floor(Math.random() * state.crib!.length);
          const handCard = state.player_hand![handIndex];
          const cribCard = state.crib![cribIndex];
          state.player_hand![handIndex] = cribCard;
          state.crib![cribIndex] = handCard;
          logEvent(
            "Pretzels swapped " +
              (cards as any).card_label(handCard) +
              " with crib " +
              (cards as any).card_label(cribCard) +
              "."
          );
          state.meta.side_effects.pretzels = false;
        }

        state.player_show_hand = copyList(state.player_hand!);
        state.ai_show_hand = copyList(state.ai_hand!);
        startCut();
      }
    }
    return;
  }

  if (state.phase === "cut") {
    if (state.cut.status === "aim") {
      if (key === "return" || key === "space") {
        state.cut.selected = Math.max(
          1,
          Math.min(state.cut.visual_size, Math.floor(state.cut.pointer + 0.5))
        );
        selectCutCard();
        state.cut.status = "clear_left";
        state.cut.timer = 0;
        state.message = "Cutting...";
      }
    }
    return;
  }

  if (state.phase === "pegging") {
    const peg = state.peg!;
    if (state.turn === "player") {
      if (key === "g" || key === "return" || key === "space") {
        if (canPlayAny(state.player_peg_hand!, peg.count)) {
          if (key === "g") {
            state.message = "You can't pass. You must play if you can peg under 31.";
          }
        } else {
          peg.player_passed = true;
          state.turn = "ai";
          applyGoIfNeeded();
          checkPeggingEnd();
        }
        return;
      }
      const index = parseInt(key, 10);
      if (!isNaN(index)) {
        if (!canPlayAny(state.player_peg_hand!, peg.count)) {
          if (state.pending_pass_key === key) {
            peg.player_passed = true;
            state.pending_pass_key = null;
            state.turn = "ai";
            applyGoIfNeeded();
            checkPeggingEnd();
          } else {
            state.pending_pass_key = key;
            state.message = "Press '" + String(key) + "' again to pass.";
          }
          return;
        }
      }
      if (!isNaN(index) && index >= 1 && index <= (state.player_peg_hand || []).length) {
        const card = state.player_peg_hand![index - 1];
        if (card.vined) {
          state.message = "That card is vined this hand.";
          return;
        }
        if ((cards as any).card_value(card) + peg.count <= 31) {
          playCard("player", index);
          applyGoIfNeeded();
          checkPeggingEnd();
        }
      }
    }
    return;
  }

  if (
    state.phase === "show_ai" ||
    state.phase === "show_crib" ||
    state.phase === "show_player" ||
    state.phase === "show_summary"
  ) {
    if (key === "return" || key === "space") {
      advanceShowPhase();
    }
    return;
  }

  if (state.phase === "street_preview") {
    if (key === "m") {
      state.phase_before_map = "street_preview";
      state.phase = "board_map";
      return;
    }
    if (key === "return" || key === "space") {
      startRound();
    }
    return;
  }

  if (state.phase === "special_use") {
    handleSpecialUseInput(key);
    return;
  }

  if (state.phase === "side_dish_use") {
    handleSideDishUseInput(key);
    return;
  }

  if (state.phase === "inventory") {
    if (key === "b" || key === "i" || key === "escape") {
      state.phase = state.view_prev || "street_preview";
      return;
    }
    const index = parseInt(key, 10);
    if (!isNaN(index)) {
      const special = state.meta.special_pouch[index - 1];
      if (special) {
        beginSpecialUse("inventory", index);
      }
    }
    return;
  }

  if (state.phase === "eat_side_dish") {
    if (key === "b" || key === "u" || key === "escape") {
      state.phase = state.view_prev || "street_preview";
      return;
    }
    const index = parseInt(key, 10);
    if (!isNaN(index)) {
      const item = state.meta.side_pouch[index - 1];
      if (item) {
        state.meta.side_pouch.splice(index - 1, 1);
        if (
          item.id === "beer" ||
          item.id === "wine" ||
          item.id === "whiskey" ||
          item.id === "pie"
        ) {
          beginSideDishUse(state.view_prev || "street_preview", item);
          return;
        }
        const applied = applySideDishEffect(item);
        if (applied) {
          state.message = "Ate " + item.name + ".";
        } else {
          state.message = "No effect for " + item.name + ".";
        }
        state.phase = state.view_prev || "street_preview";
      }
    }
    return;
  }

  if (state.phase === "deck_view") {
    if (key === "b" || key === "d" || key === "escape") {
      state.phase = state.view_prev || "street_preview";
      return;
    }
    if (key === "n") {
      state.deck_view_page = (state.deck_view_page || 1) + 1;
      return;
    }
    if (key === "p" && (state.deck_view_page || 1) > 1) {
      state.deck_view_page = (state.deck_view_page || 1) - 1;
      return;
    }
  }

  if (state.phase === "board_map") {
    if (key === "m" || key === "escape" || key === "return") {
      state.phase = state.phase_before_map || "street_preview";
      return;
    }
  }

  if (state.phase === "shop") {
    const shop = state.shop;
    if (key === "return" || key === "space") {
      if (shop.state === "intro") {
        shop.state = "active";
        shop.message =
          "Shop: 1-5 buy family, 6-0 buy dishes, R/T reroll, X sell last, E enhancements, C buy special, U use special.";
      } else if (shop.state === "active") {
        if (state.meta.side_effects.extra_shop_action > 0) {
          state.meta.side_effects.extra_shop_action -= 1;
          shop.message = "Extra shop action used. Continue shopping.";
          return;
        }
        state.dealer = toggleDealer(state.dealer);
        advanceStreet();
        enterStreetPreview();
      }
      return;
    }

    if (shop.state !== "active") {
      // handle enhance_select and enhance_card sub-states below
    } else {
      if (key === "e") {
        shop.state = "enhance_select";
        shop.selected_enhancement = null;
        shop.enhancement_message = "Select enhancement (1-9).";
        return;
      }

      if (key === "c" && shop.special_offer) {
        if (state.meta.special_pouch.length >= state.meta.special_pouch_capacity) {
          shop.message = "Special pouch full.";
        } else if (state.meta.money < shop.special_offer.cost) {
          shop.message = "Not enough money.";
        } else {
          state.meta.money -= shop.special_offer.cost;
          state.meta.special_pouch.push(shop.special_offer);
          shop.message = "Bought " + shop.special_offer.name + ".";
          logEvent("Bought special card: " + shop.special_offer.name + ".");
          shop.special_offer = null;
        }
        return;
      }

      if (key === "u" && state.meta.side_pouch.length > 0) {
        state.view_prev = "shop";
        state.phase = "eat_side_dish";
        return;
      }

      if (key === "r") {
        if (state.meta.money >= shop.family_reroll_cost) {
          state.meta.money -= shop.family_reroll_cost;
          shop.family_reroll_cost = Math.min(5, shop.family_reroll_cost + 1);
          [shop.family_stock] = buildShopStock();
        } else {
          shop.message = "Not enough money to reroll family.";
        }
        return;
      }

      if (key === "t") {
        if (state.meta.money >= shop.dish_reroll_cost) {
          state.meta.money -= shop.dish_reroll_cost;
          shop.dish_reroll_cost = Math.min(5, shop.dish_reroll_cost + 1);
          [, shop.dish_stock] = buildShopStock();
        } else {
          shop.message = "Not enough money to reroll dishes.";
        }
        return;
      }

      if (key === "x") {
        const last = state.meta.family[state.meta.family.length - 1];
        if (last) {
          const refund = Math.max(1, Math.floor((last.cost || 1) / 2));
          state.meta.money += refund;
          state.meta.family.pop();
          shop.message = "Sold " + last.name + " for $" + String(refund) + ".";
        } else {
          shop.message = "No family to sell.";
        }
        return;
      }

      let index = parseInt(key, 10);
      if (!isNaN(index)) {
        if (index >= 1 && index <= 5) {
          const item = shop.family_stock[index - 1];
          if (item) {
            if (state.meta.family.length >= state.meta.family_slots) {
              shop.message = "Family slots full. Sell one first.";
              return;
            }
            if (state.meta.money >= item.cost) {
              state.meta.money -= item.cost;
              state.meta.family.push(item);
              shop.message = "Hired " + item.name + ".";
              logEvent("Hired family: " + item.name + ".");
            } else {
              shop.message = "Not enough money.";
            }
          }
          return;
        }

        if (index === 0) index = 10;
        if (index >= 6 && index <= 10) {
          const dishIndex = index - 6; // 0-based: dish_stock[0] = key 6
          const item = shop.dish_stock[dishIndex];
          if (item) {
            if (state.meta.side_pouch.length >= state.meta.side_pouch_capacity) {
              shop.message = "Side dish pouch full.";
              return;
            }
            if (state.meta.money >= item.cost) {
              state.meta.money -= item.cost;
              state.meta.side_pouch.push(item);
              shop.message = "Bought " + item.name + ".";
              logEvent("Bought side dish: " + item.name + ".");
            } else {
              shop.message = "Not enough money.";
            }
          }
          return;
        }
      }
    }
  }

  // Second shop block for enhance sub-states
  if (state.phase === "shop") {
    const shop = state.shop;
    if (shop.state === "enhance_select") {
      if (key === "n") {
        shop.enhancement_select_page = (shop.enhancement_select_page || 1) + 1;
        return;
      }
      if (key === "p" && (shop.enhancement_select_page || 1) > 1) {
        shop.enhancement_select_page = (shop.enhancement_select_page || 1) - 1;
        return;
      }
      const index = parseInt(key, 10);
      if (!isNaN(index)) {
        const list = enhancementShopList();
        const perPage = 9;
        const [pageItems] = listPage(list, shop.enhancement_select_page || 1, perPage);
        const enhancement = pageItems[index - 1];
        if (enhancement) {
          shop.selected_enhancement = enhancement;
          shop.state = "enhance_card";
          shop.enhancement_page = 1;
          shop.enhancement_message = "Pick a card (1-9). N/P to page. B to back.";
        } else {
          shop.enhancement_message = "Invalid enhancement.";
        }
      } else if (key === "b") {
        shop.state = "active";
        shop.enhancement_message = null;
      }
      return;
    }

    if (shop.state === "enhance_card") {
      if (key === "b") {
        shop.state = "enhance_select";
        shop.enhancement_message = "Select enhancement (1-9).";
        return;
      }
      if (key === "n") {
        shop.enhancement_page += 1;
        return;
      }
      if (key === "p" && shop.enhancement_page > 1) {
        shop.enhancement_page -= 1;
        return;
      }
      const index = parseInt(key, 10);
      if (!isNaN(index)) {
        const deck = currentDeckForView();
        const perPage = 9;
        const [pageItems] = deckPage(deck, shop.enhancement_page, perPage);
        const card = pageItems[index - 1];
        if (card && shop.selected_enhancement) {
          const card_id = (cards as any).card_id(card);
          if (state.meta.enhancements[card_id]) {
            shop.enhancement_message = "Card already enhanced.";
            return;
          }
          if (state.meta.money < shop.selected_enhancement.cost) {
            shop.enhancement_message = "Not enough money.";
            return;
          }
          state.meta.money -= shop.selected_enhancement.cost;
          state.meta.enhancements[card_id] = shop.selected_enhancement.id;
          shop.state = "active";
          shop.enhancement_message =
            "Enhanced " +
            (cards as any).card_label(card) +
            " with " +
            shop.selected_enhancement.name +
            ".";
          logEvent(
            "Enhanced " +
              (cards as any).card_label(card) +
              " with " +
              shop.selected_enhancement.name +
              "."
          );
        }
      }
      return;
    }
  }

  if (state.phase === "run_end") {
    if (key === "r") {
      startNewRun();
    }
  }
}

export function mousepressed(x: number, y: number, button: number): void {
  if (USE_BALATRO_MODE) {
    if ((balatrMode as any).mousepressed) {
      (balatrMode as any).mousepressed(x, y, button);
    }
    return;
  }
}

export function draw(ctx: CanvasRenderingContext2D): void {
  if (USE_BALATRO_MODE) {
    (balatrMode as any).draw(ctx);
    return;
  }
  internalDraw(ctx);
}
