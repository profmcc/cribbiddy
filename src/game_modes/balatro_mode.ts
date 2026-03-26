import * as cards from "../cards.ts";
import * as scoring from "../scoring.ts";
import * as ui from "../ui.ts";
import * as aunties from "../data/aunties.ts";
import * as sideDishes from "../data/side_dishes.ts";
import * as boards from "../data/boards.ts";
import * as Characters from "../characters.ts";
import * as CharacterSelect from "../character_select.ts";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

interface Card {
  rank: number;
  suit: number;
  locked?: boolean;
  eternal?: boolean;
  pinned?: boolean;
  enhancement?: string;
  original_rank?: number;
}

interface AuntieItem {
  id: string;
  name: string;
  effect: string;
  cost: number;
}

interface DishItem {
  id: string;
  name: string;
  effect: string;
  cost: number;
}

interface ScoreBreakdownEntry {
  type: string;
  points: number;
  length?: number;
}

interface HandScore {
  total: number;
  breakdown: (string | ScoreBreakdownEntry)[];
  details: any;
}

interface HandHistoryEntry {
  cards: Card[];
}

interface LastHand {
  cards: Card[];
  total: number;
  breakdown: (string | ScoreBreakdownEntry)[];
  details: any;
  indices: number[];
}

interface ScoreAnim {
  from: number;
  to: number;
  delta: number;
  phase: "show_delta" | "slide_in";
  timer: number;
  duration: number;
}

interface Objective {
  label: string;
  failed: boolean;
  complete: boolean;
  hands_checked: number;
}

interface Shop {
  family_stock: AuntieItem[];
  dish_stock: DishItem[];
}

interface RewardBreakdown {
  base: number;
  performance: number;
  perfect: number;
  hands_saved: number;
}

interface InventoryUse {
  kind: "uncle" | "dish";
  item: AuntieItem | DishItem;
  index?: number;
  requires_card: boolean;
}

interface ActiveUse {
  mode: "swap_one" | "pick_tea_stain";
}

interface Street {
  id: number;
  name: string;
  condition: string;
  objective: string;
}

interface Board {
  name: string;
  subtitle: string;
  streets: Street[];
}

interface CharacterActive {
  name: string;
  stained_card?: { suit: number; original_rank: number };
  canTrigger: (self: CharacterActive, state: any) => boolean;
  onActivate: (self: CharacterActive, state: any) => any;
}

interface Character {
  active?: CharacterActive;
  death_text?: string;
}

interface GameState {
  round_index: number;
  target_score: number;
  base_hand_size: number;
  hand_size_bonus: number;
  display_round_score: number;
  character: Character | null;
  bonus_shop_gold: number;
  starter_peeked: boolean;
  street_failed: boolean;
  last_hand_score: number;
  phase: string;
  screen: string;
  // Runtime state
  deck: Card[];
  player_hand: Card[];
  starter_card: Card | null;
  discards_remaining: number;
  hands_remaining: number;
  current_round_score: number;
  hand_scores: HandScore[];
  hand_history: HandHistoryEntry[];
  last_hand: LastHand | null;
  discard_pile: Card[];
  round_reward: number | null;
  reward_breakdown: RewardBreakdown | null;
  character_phase: string;
  objective: Objective | null;
  selected_cards: { [index: number]: boolean };
  message: string | null;
  money: number;
  total_earned: number;
  family: string[];
  family_slots: number;
  side_pouch: DishItem[];
  side_pouch_capacity: number;
  auntie_lookup: { [id: string]: AuntieItem };
  dish_lookup: { [id: string]: DishItem };
  auntie_pool: AuntieItem[];
  dish_pool: DishItem[];
  board: Board | null;
  shop: Shop | null;
  score_anim: ScoreAnim | null;
  log_path: string | null;
  inventory_return_phase?: string;
  inventory_use?: InventoryUse | null;
  active_use?: ActiveUse | null;
  history_return_phase?: string;
  discard_return_phase?: string;
  discard_view_page?: number;
  deck_return_phase?: string;
  deck_view_page?: number;
  map_return_phase?: string;
  big_font?: string;
}

// ---------------------------------------------------------------------------
// Module-level state
// ---------------------------------------------------------------------------

let state: GameState = {
  round_index: 1,
  target_score: 36,
  base_hand_size: 6,
  hand_size_bonus: 0,
  display_round_score: 0,
  character: null,
  bonus_shop_gold: 0,
  starter_peeked: false,
  street_failed: false,
  last_hand_score: 0,
  phase: "character_select",
  screen: "character_select",
  // Runtime state initialised as empty; populated in load/start_round
  deck: [],
  player_hand: [],
  starter_card: null,
  discards_remaining: 0,
  hands_remaining: 0,
  current_round_score: 0,
  hand_scores: [],
  hand_history: [],
  last_hand: null,
  discard_pile: [],
  round_reward: null,
  reward_breakdown: null,
  character_phase: "discard",
  objective: null,
  selected_cards: {},
  message: null,
  money: 0,
  total_earned: 0,
  family: [],
  family_slots: 3,
  side_pouch: [],
  side_pouch_capacity: 3,
  auntie_lookup: {},
  dish_lookup: {},
  auntie_pool: [],
  dish_pool: [],
  board: null,
  shop: null,
  score_anim: null,
  log_path: null,
};

// ---------------------------------------------------------------------------
// Drawing helpers
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

function roundedRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  rx: number
): void {
  const r = Math.min(rx, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.arcTo(x + w, y, x + w, y + r, r);
  ctx.lineTo(x + w, y + h - r);
  ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
  ctx.lineTo(x + r, y + h);
  ctx.arcTo(x, y + h, x, y + h - r, r);
  ctx.lineTo(x, y + r);
  ctx.arcTo(x, y, x + r, y, r);
  ctx.closePath();
}

function printAligned(
  ctx: CanvasRenderingContext2D,
  text: string,
  x: number,
  y: number,
  w: number,
  align: string
): void {
  ctx.textAlign = align as CanvasTextAlign;
  const drawX = align === "center" ? x + w / 2 : align === "right" ? x + w : x;
  ctx.fillText(text, drawX, y + 14);
  ctx.textAlign = "left";
}

// ---------------------------------------------------------------------------
// Pure helper functions
// ---------------------------------------------------------------------------

function target_for_round(round_index: number): number {
  return 36 + (round_index - 1) * 6;
}

function discards_for_round(_round_index: number): number {
  return 6;
}

function current_hand_size(): number {
  return (state.base_hand_size || 9) + (state.hand_size_bonus || 0);
}

function base_reward_for_round(round_index: number): number {
  if (round_index === 1) return 3;
  if (round_index === 2) return 4;
  if (round_index === 3) return 5;
  return 6;
}

function performance_bonus(score: number, target: number): number {
  if (score <= target) return 0;
  const ratio = (score - target) / target;
  if (ratio >= 0.3) return 3;
  if (ratio >= 0.2) return 2;
  if (ratio >= 0.1) return 1;
  return 0;
}

function calculate_round_reward(
  score: number,
  target: number,
  round_index: number,
  discards_remaining: number,
  hands_remaining: number
): [number, RewardBreakdown] {
  const base_reward = base_reward_for_round(round_index);
  const perf_bonus = performance_bonus(score, target);
  const discards_used = discards_for_round(round_index) - discards_remaining;
  const perfect_bonus = discards_used === 0 ? 1 : 0;
  const hands_saved_bonus = Math.max(0, hands_remaining);
  const total = base_reward + perf_bonus + perfect_bonus + hands_saved_bonus;
  return [
    total,
    {
      base: base_reward,
      performance: perf_bonus,
      perfect: perfect_bonus,
      hands_saved: hands_saved_bonus,
    },
  ];
}

function begin_run_log(): void {
  const now = new Date();
  const pad = (n: number) => n.toString().padStart(2, "0");
  const timestamp =
    `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}` +
    `_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
  const name = `cribbiddy_run_${timestamp}.log`;
  state.log_path = name;
  const header = [
    "Cribbiddy run log",
    `Started: ${now.toLocaleString()}`,
    "Seed: (browser)",
    "",
  ].join("\n");
  localStorage.setItem(name, header);
}

function log_event(message: string): void {
  if (!state.log_path) return;
  const now = new Date();
  const pad = (n: number) => n.toString().padStart(2, "0");
  const time = `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
  const line = `${time} | ${message}\n`;
  const existing = localStorage.getItem(state.log_path) || "";
  localStorage.setItem(state.log_path, existing + line);
}

function build_score_breakdown(
  hand: Card[],
  starter: Card | null,
  details: any
): ScoreBreakdownEntry[] {
  const breakdown: ScoreBreakdownEntry[] = [];
  const counts: { [rank: number]: number } = {};
  for (const card of hand) {
    counts[card.rank] = (counts[card.rank] || 0) + 1;
  }
  if (starter) {
    counts[starter.rank] = (counts[starter.rank] || 0) + 1;
  }

  for (const count of Object.values(counts)) {
    if (count === 2) {
      breakdown.push({ type: "pair", points: 2 });
    } else if (count === 3) {
      breakdown.push({ type: "triple", points: 6 });
    } else if (count === 4) {
      breakdown.push({ type: "quad", points: 12 });
    }
  }

  if (details && details.fifteens) {
    for (let i = 0; i < details.fifteens.length; i++) {
      breakdown.push({ type: "fifteen", points: 2 });
    }
  }
  if (details && details.runs) {
    for (let i = 0; i < details.runs.length; i++) {
      breakdown.push({
        type: "run",
        points: details.runs[i].points,
        length: details.runs[i].points,
      });
    }
  }
  if (details && details.flush) {
    breakdown.push({ type: "flush", points: details.flush.points });
  }
  if (details && details.knobs) {
    breakdown.push({ type: "nobs", points: details.knobs.points });
  }
  return breakdown;
}

function clone_card(card: Card): Card {
  return { ...card };
}

function score_with_tea_stain(
  hand: Card[],
  starter: Card | null,
  character: Character | null
): [number, any, any] {
  const stained =
    character && character.active && character.active.stained_card
      ? character.active.stained_card
      : null;
  if (!stained) {
    return scoring.score_hand(hand, starter, false);
  }

  const is_stained = (card: Card) =>
    card.suit === stained.suit && card.original_rank === stained.original_rank;

  let target_index: number | null = null;
  for (let i = 0; i < hand.length; i++) {
    if (is_stained(hand[i])) {
      target_index = i;
      break;
    }
  }

  if (target_index === null) {
    if (starter && is_stained(starter)) {
      const alt = clone_card(starter);
      let [best_total, best_breakdown, best_details] = scoring.score_hand(
        hand,
        starter,
        false
      );
      for (let rank = 1; rank <= 13; rank++) {
        alt.rank = rank;
        const [total, breakdown, details] = scoring.score_hand(hand, alt, false);
        if (total > best_total) {
          best_total = total;
          best_breakdown = breakdown;
          best_details = details;
        }
      }
      return [best_total, best_breakdown, best_details];
    }
    return scoring.score_hand(hand, starter, false);
  }

  let [best_total, best_breakdown, best_details] = scoring.score_hand(
    hand,
    starter,
    false
  );
  for (let rank = 1; rank <= 13; rank++) {
    const alt_hand: Card[] = [];
    for (let i = 0; i < hand.length; i++) {
      alt_hand.push(clone_card(hand[i]));
    }
    alt_hand[target_index].rank = rank;
    const [total, breakdown, details] = scoring.score_hand(
      alt_hand,
      starter,
      false
    );
    if (total > best_total) {
      best_total = total;
      best_breakdown = breakdown;
      best_details = details;
    }
  }
  return [best_total, best_breakdown, best_details];
}

function count_selected(selection: { [index: number]: boolean }): number {
  let count = 0;
  for (const selected of Object.values(selection)) {
    if (selected) count++;
  }
  return count;
}

function build_auntie_lookup(): { [id: string]: AuntieItem } {
  const lookup: { [id: string]: AuntieItem } = {};
  for (const group of aunties.universal || []) {
    for (const item of group.items || []) {
      lookup[item.id] = item;
    }
  }
  return lookup;
}

function build_dish_lookup(): { [id: string]: DishItem } {
  const lookup: { [id: string]: DishItem } = {};
  for (const item of sideDishes.universal || []) {
    lookup[item.id] = item;
  }
  return lookup;
}

function flatten_aunties(): AuntieItem[] {
  const list: AuntieItem[] = [];
  for (const group of aunties.universal || []) {
    for (const item of group.items || []) {
      list.push(item);
    }
  }
  return list;
}

function flatten_dishes(): DishItem[] {
  const list: DishItem[] = [];
  for (const item of sideDishes.universal || []) {
    list.push(item);
  }
  return list;
}

function pick_random<T>(source: T[], count: number): T[] {
  const pool: T[] = source.slice();
  const picked: T[] = [];
  for (let i = 0; i < Math.min(count, pool.length); i++) {
    const index = Math.floor(Math.random() * pool.length);
    picked.push(pool.splice(index, 1)[0]);
  }
  return picked;
}

function remove_indices(list: any[], indices: number[]): any[] {
  // indices are 1-based (Lua); convert to 0-based JS
  indices.sort((a, b) => b - a);
  const removed: any[] = [];
  for (const index of indices) {
    removed.push(list.splice(index - 1, 1)[0]);
  }
  return removed;
}

function collect_selected_cards(
  hand: Card[],
  selection: { [index: number]: boolean }
): Card[] {
  const picked: Card[] = [];
  // selection keys are 1-based
  for (let i = 1; i <= hand.length; i++) {
    if (selection[i]) {
      picked.push(hand[i - 1]);
    }
  }
  return picked;
}

function collect_selected_indices(selection: {
  [index: number]: boolean;
}): number[] {
  const indices: number[] = [];
  for (const key of Object.keys(selection)) {
    const i = parseInt(key, 10);
    if (selection[i]) indices.push(i);
  }
  indices.sort((a, b) => a - b);
  return indices;
}

function single_selected_index(selection: {
  [index: number]: boolean;
}): number | null {
  let index: number | null = null;
  for (const key of Object.keys(selection)) {
    const i = parseInt(key, 10);
    if (selection[i]) {
      if (index !== null) return null;
      index = i;
    }
  }
  return index;
}

function most_common_rank_in_hand(
  hand: Card[],
  exclude_index: number | null
): number | null {
  // exclude_index is 1-based
  const counts: { [rank: number]: number } = {};
  for (let i = 0; i < hand.length; i++) {
    const lua_i = i + 1;
    if (lua_i !== exclude_index) {
      counts[hand[i].rank] = (counts[hand[i].rank] || 0) + 1;
    }
  }
  let best_rank: number | null = null;
  let best_count = 0;
  for (const [rankStr, count] of Object.entries(counts)) {
    const rank = parseInt(rankStr, 10);
    if (count > best_count) {
      best_rank = rank;
      best_count = count;
    }
  }
  return best_rank;
}

function apply_uncle(
  item: AuntieItem,
  target_index: number | null
): [boolean, string] {
  if (state.money < (item.cost || 0)) {
    return [false, `Not enough money for ${item.name}.`];
  }

  const name = item.id;
  if (name === "uncle_bramble") {
    const card = target_index !== null ? state.player_hand[target_index - 1] : null;
    if (!card) return [false, "No card selected."];
    if (card.locked || card.eternal) return [false, "That card can't be transformed."];
    card.rank = 5;
  } else if (name === "uncle_cedar") {
    const card = target_index !== null ? state.player_hand[target_index - 1] : null;
    if (!card) return [false, "No card selected."];
    if (card.locked || card.eternal) return [false, "That card can't be transformed."];
    card.rank = Math.min(card.rank + 1, 13);
  } else if (name === "uncle_oakley") {
    const card = target_index !== null ? state.player_hand[target_index - 1] : null;
    if (!card) return [false, "No card selected."];
    if (card.locked || card.eternal) return [false, "That card can't be transformed."];
    const rank = most_common_rank_in_hand(state.player_hand, target_index);
    if (rank === null) return [false, "No matching rank available."];
    card.rank = rank;
  } else if (name === "uncle_birch") {
    const card = target_index !== null ? state.player_hand[target_index - 1] : null;
    if (!card) return [false, "No card selected."];
    if (card.locked || card.eternal) return [false, "That card can't be transformed."];
    const choices = [10, 11, 12, 13];
    card.rank = choices[Math.floor(Math.random() * choices.length)];
  } else if (name === "uncle_sage") {
    for (let i = 0; i < 2; i++) {
      state.deck.push({
        rank: Math.floor(Math.random() * 13) + 1,
        suit: Math.floor(Math.random() * 4) + 1,
      });
    }
  } else if (name === "uncle_ash") {
    const card = target_index !== null ? state.player_hand[target_index - 1] : null;
    if (!card) return [false, "No card selected."];
    card.enhancement = "golden_card";
  } else if (name === "uncle_rowan") {
    const card = target_index !== null ? state.player_hand[target_index - 1] : null;
    if (!card) return [false, "No card selected."];
    if (card.locked || card.eternal) return [false, "That card can't be transformed."];
    card.suit = 4;
  } else if (name === "uncle_sycamore") {
    const card = target_index !== null ? state.player_hand[target_index - 1] : null;
    if (!card) return [false, "No card selected."];
    if (card.locked || card.eternal) return [false, "That card can't be transformed."];
    card.suit = 2;
  } else if (name === "uncle_cypress") {
    const card = target_index !== null ? state.player_hand[target_index - 1] : null;
    if (!card) return [false, "No card selected."];
    if (card.locked || card.eternal) return [false, "That card can't be transformed."];
    card.suit = 3;
  } else if (name === "uncle_elm") {
    const card = target_index !== null ? state.player_hand[target_index - 1] : null;
    if (!card) return [false, "No card selected."];
    if (card.locked || card.eternal) return [false, "That card can't be transformed."];
    card.suit = 1;
  } else if (name === "uncle_hickory") {
    for (let i = 0; i < Math.min(2, state.deck.length); i++) {
      const idx = Math.floor(Math.random() * state.deck.length);
      state.deck.splice(idx, 1);
    }
    state.money = state.money + 4;
  } else if (name === "uncle_willow") {
    const card = target_index !== null ? state.player_hand[target_index - 1] : null;
    if (!card) return [false, "No card selected."];
    if (card.locked || card.eternal) return [false, "That card can't be transformed."];
    const target_rank = card.rank;
    for (let i = 0; i < state.player_hand.length; i++) {
      state.player_hand[i].rank = target_rank;
    }
  } else if (name === "uncle_chestnut") {
    const card = target_index !== null ? state.player_hand[target_index - 1] : null;
    if (!card) return [false, "No card selected."];
    if (card.locked || card.eternal) return [false, "That card can't be transformed."];
    card.enhancement = "toy_card";
  } else if (name === "uncle_alder") {
    for (let i = 0; i < state.player_hand.length; i++) {
      state.player_hand[i].rank = Math.floor(Math.random() * 13) + 1;
    }
  } else if (name === "uncle_linden") {
    const card = target_index !== null ? state.player_hand[target_index - 1] : null;
    if (!card) return [false, "No card selected."];
    state.deck.push({ rank: card.rank, suit: card.suit });
  } else {
    return [false, "That Uncle's effect isn't available yet."];
  }

  state.money = state.money - (item.cost || 0);
  return [true, `Used ${item.name}.`];
}

function apply_side_dish(
  item: DishItem,
  target_index: number | null
): [boolean, string] {
  const card = target_index !== null ? state.player_hand[target_index - 1] : null;
  if (!card) return [false, "No card selected."];
  if (card.locked || card.eternal) return [false, "That card can't be modified."];

  if (item.id === "negative_card") {
    state.hand_size_bonus = (state.hand_size_bonus || 0) + 1;
    return [true, `Used ${item.name}.`];
  }

  if (item.id === "pinned_card") {
    card.pinned = true;
  } else if (item.id === "steel_card") {
    card.locked = true;
  } else if (item.id === "eternal_card") {
    card.eternal = true;
  }

  card.enhancement = item.id;
  return [true, `Used ${item.name}.`];
}

function point_in_rect(x: number, y: number, rect: Rect): boolean {
  return x >= rect.x && x <= rect.x + rect.w && y >= rect.y && y <= rect.y + rect.h;
}

function hand_index_at(
  x: number,
  y: number,
  hand_x: number,
  hand_y: number,
  hand_count: number
): number | null {
  const [card_w, card_h, gap] = ui.card_dimensions();
  for (let i = 0; i < hand_count; i++) {
    const card_x = hand_x + i * (card_w + gap);
    if (x >= card_x && x <= card_x + card_w && y >= hand_y && y <= hand_y + card_h) {
      return i + 1; // return 1-based index
    }
  }
  return null;
}

function inventory_hitbox(): Rect {
  const width = 110;
  const height = 18;
  return { x: 900, y: 20, w: width, h: height };
}

function enter_button_rect(): Rect {
  return { x: 30, y: 610, w: 90, h: 28 };
}

function sort_rank_button_rect(): Rect {
  return { x: 130, y: 610, w: 110, h: 28 };
}

function sort_suit_button_rect(): Rect {
  return { x: 250, y: 610, w: 110, h: 28 };
}

function shop_family_item_rect(index: number): Rect {
  // index is 1-based
  const y = 320 + (index - 1) * 18;
  return { x: 30, y, w: 170, h: 18 };
}

function shop_dish_item_rect(index: number, family_count: number): Rect {
  // index is 1-based
  const base = 320 + family_count * 18 + 48;
  const y = base + (index - 1) * 18;
  return { x: 30, y, w: 170, h: 18 };
}

function inventory_family_item_rect(index: number): Rect {
  // index is 1-based
  const y = 320 + (index - 1) * 18;
  return { x: 30, y, w: 420, h: 18 };
}

function inventory_dish_item_rect(index: number, family_count: number): Rect {
  // index is 1-based
  const y = 320 + family_count * 18 + 48 + (index - 1) * 18;
  return { x: 30, y, w: 420, h: 18 };
}

function confirm_accept_rect(): Rect {
  return { x: 30, y: 610, w: 90, h: 28 };
}

function confirm_cancel_rect(): Rect {
  return { x: 130, y: 610, w: 90, h: 28 };
}

function active_button_rect(): Rect {
  return { x: 370, y: 610, w: 180, h: 28 };
}

function history_button_rect(): Rect {
  return { x: 560, y: 610, w: 110, h: 28 };
}

function character_state_view(): any {
  // Returns a proxy-like view of state with overridden phase
  return new Proxy(state as any, {
    get(target, prop) {
      if (prop === "phase") return state.character_phase || state.phase;
      return (target as any)[prop];
    },
    set(target, prop, value) {
      (target as any)[prop] = value;
      return true;
    },
  });
}

function active_can_trigger(): boolean {
  if (!state.character || !state.character.active || !state.character.active.canTrigger) {
    return false;
  }
  return state.character.active.canTrigger(state.character.active, character_state_view());
}

function trigger_active(): void {
  if (!state.character || !state.character.active) return;
  const view = character_state_view();
  if (!state.character.active.canTrigger(state.character.active, view)) return;
  const result = state.character.active.onActivate(state.character.active, view);
  if (typeof result === "number") {
    state.current_round_score = state.current_round_score + result;
    state.display_round_score = state.current_round_score;
    state.message = `${state.character.active.name}: +${String(result)}`;
    return;
  }
  if (result === "swap_one") {
    state.active_use = { mode: "swap_one" };
    reset_selection();
    state.phase = "active_target";
    state.message = "Pick a card to swap with the top of your deck.";
    return;
  }
  if (result === "pick_tea_stain") {
    state.active_use = { mode: "pick_tea_stain" };
    reset_selection();
    state.phase = "active_target";
    state.message = "Pick a card to tea-stain permanently.";
    return;
  }
  if (result === "peek_starter") {
    if (state.deck.length > 0) {
      state.message = "Peeked: " + cards.card_label(state.deck[state.deck.length - 1]);
    } else {
      state.message = "No cards left to peek.";
    }
  }
}

function build_combo_entries(details: any): { label: string; cards?: Card[] }[] {
  const entries: { label: string; cards?: Card[] }[] = [];
  if (details && details.fifteens) {
    for (let i = 0; i < details.fifteens.length; i++) {
      entries.push({
        label: `15 for ${String(details.fifteens[i].points)}`,
        cards: details.fifteens[i].cards,
      });
    }
  }
  if (details && details.pairs) {
    for (let i = 0; i < details.pairs.length; i++) {
      entries.push({
        label: `Pair for ${String(details.pairs[i].points)}`,
        cards: details.pairs[i].cards,
      });
    }
  }
  if (details && details.runs) {
    for (let i = 0; i < details.runs.length; i++) {
      entries.push({
        label: `${details.runs[i].label} for ${String(details.runs[i].points)}`,
        cards: details.runs[i].cards,
      });
    }
  }
  if (details && details.flush) {
    entries.push({
      label: `${details.flush.label} for ${String(details.flush.points)}`,
      cards: details.flush.cards,
    });
  }
  if (details && details.knobs) {
    entries.push({
      label: `${details.knobs.label} for ${String(details.knobs.points)}`,
      cards: details.knobs.cards,
    });
  }
  if (entries.length === 0) {
    entries.push({ label: "No score" });
  }
  return entries;
}

function reset_selection(): void {
  state.selected_cards = {};
}

function sort_hand_by_rank(hand: Card[]): void {
  hand.sort((a, b) => {
    if (a.rank === b.rank) return a.suit - b.suit;
    return a.rank - b.rank;
  });
}

function sort_hand_by_suit(hand: Card[]): void {
  hand.sort((a, b) => {
    if (a.suit === b.suit) return a.rank - b.rank;
    return a.suit - b.suit;
  });
}

// ---------------------------------------------------------------------------
// Drawing sub-functions
// ---------------------------------------------------------------------------

function draw_top_bar(ctx: CanvasRenderingContext2D): void {
  setColor(ctx, 1, 1, 1);
  ctx.fillText(`Level: ${String(state.round_index)}`, 30, 20 + 14);
  ctx.fillText(`Money: $${String(state.money || 0)}`, 150, 20 + 14);
  ctx.fillText(`Discards: ${String(state.discards_remaining || 0)}`, 280, 20 + 14);
  ctx.fillText(`Hands: ${String(state.hands_remaining || 0)}`, 430, 20 + 14);
  ctx.fillText(
    `Round Score: ${String(state.display_round_score || state.current_round_score || 0)}`,
    560,
    20 + 14
  );
  ctx.fillText(`Target: ${String(state.target_score || 0)}`, 760, 20 + 14);
  const inv = inventory_hitbox();
  ctx.lineWidth = 1;
  roundedRect(ctx, inv.x - 6, inv.y - 4, inv.w + 12, inv.h + 8, 6);
  ctx.stroke();
  ctx.fillText("Inventory (I)", 900, 20 + 14);
}

function draw_board_panel(ctx: CanvasRenderingContext2D): void {
  const board = state.board;
  if (!board) return;
  const street = board.streets[state.round_index - 1];
  const next_street = board.streets[state.round_index]; // round_index+1 in Lua, 0-based here
  const lines: string[] = [
    `Board: ${board.name} (${board.subtitle})`,
  ];
  if (street) {
    lines.push(`Street ${String(street.id)}: ${street.name}`);
    lines.push(`Condition: ${street.condition}`);
    lines.push(`Objective: ${street.objective}`);
  }
  if (next_street) {
    lines.push(`Next: ${String(next_street.id)} - ${next_street.name}`);
    lines.push(`Next condition: ${next_street.condition}`);
    lines.push(`Next objective: ${next_street.objective}`);
  }
  ui.draw_text_block(ctx, lines, 520, 70);
}

function draw_family_panel(ctx: CanvasRenderingContext2D): void {
  setColor(ctx, 1, 1, 1);
  ctx.fillText(
    `Family (${String(state.family.length)}/${String(state.family_slots)}):`,
    520,
    320 + 14
  );
  let y = 340;
  for (let i = 0; i < state.family.length; i++) {
    const item = state.auntie_lookup[state.family[i]];
    if (item) {
      ctx.fillText(`- ${item.name}: ${item.effect}`, 520, y + 14);
      y = y + 18;
    }
  }
}

function draw_starter(ctx: CanvasRenderingContext2D): void {
  if (!state.starter_card) return;
  setColor(ctx, 1, 1, 1);
  ctx.fillText("Cut card", 30, 110 + 14);
  ui.draw_face_up_card(ctx, state.starter_card, 30, 130);
}

function get_big_font(): string {
  if (!state.big_font) {
    state.big_font = "48px monospace";
  }
  return state.big_font;
}

function draw_round_score_display(ctx: CanvasRenderingContext2D): void {
  const normalFont = ctx.font;
  const bigFont = get_big_font();
  ctx.font = bigFont;
  const base_x = 220;
  const base_y = 130;
  const display_value = state.display_round_score || 0;
  let label = String(display_value);

  if (state.score_anim && state.score_anim.phase === "slide_in") {
    const t = Math.min(1, state.score_anim.timer / state.score_anim.duration);
    const start_y = base_y + 40;
    const draw_y = start_y + (base_y - start_y) * t;
    label = String(state.score_anim.to);
    ctx.fillText(label, base_x, draw_y + 14);
  } else {
    ctx.fillText(label, base_x, base_y + 14);
  }

  if (state.score_anim && state.score_anim.phase === "show_delta") {
    ctx.font = normalFont;
    ctx.fillText(`+${String(state.score_anim.delta)}`, base_x + 10, base_y + 50 + 14);
  }

  ctx.font = normalFont;
  ctx.fillText("Round score", base_x, base_y - 28 + 14);
}

function draw_card_page(
  ctx: CanvasRenderingContext2D,
  cards_list: Card[],
  page: number,
  per_page: number,
  x: number,
  y: number
): [number, number] {
  // page is 1-based; returns 1-based start/end indices for display
  const start_index = (page - 1) * per_page + 1;
  const end_index = Math.min(cards_list.length, start_index + per_page - 1);
  const display: Card[] = [];
  for (let i = start_index; i <= end_index; i++) {
    display.push(cards_list[i - 1]);
  }
  if (display.length > 0) {
    ui.draw_cards_row(ctx, display, x, y);
  }
  return [start_index, end_index];
}

// ---------------------------------------------------------------------------
// Public API: start_round (also called from keypressed)
// ---------------------------------------------------------------------------

export function start_round(): void {
  const deck = cards.shuffle(cards.build_deck({}));
  state.deck = deck;
  state.player_hand = [];
  const hs = current_hand_size();
  for (let i = 0; i < hs; i++) {
    state.player_hand.push(state.deck.pop()!);
  }
  state.starter_card = state.deck.pop()!;
  state.discards_remaining = discards_for_round(state.round_index);
  state.hands_remaining = 4;
  state.current_round_score = 0;
  state.display_round_score = 0;
  state.hand_scores = [];
  state.hand_history = [];
  state.last_hand = null;
  state.discard_pile = [];
  state.round_reward = null;
  state.reward_breakdown = null;
  state.character_phase = "discard";
  state.street_failed = false;
  state.starter_peeked = false;
  state.objective = {
    label: "Score a fifteen every hand this round",
    failed: false,
    complete: false,
    hands_checked: 0,
  };
  state.phase = "select_hand";
  state.message = null;
  reset_selection();
  if (state.character) {
    Characters.onStreetStart(state.character, state);
  }
}

// ---------------------------------------------------------------------------
// Exported module functions
// ---------------------------------------------------------------------------

export function load(ctx: CanvasRenderingContext2D): void {
  // noop: canvas has black bg
  ui.set_font(ctx);
  state.board =
    boards.boards && (boards.boards as any).Backyard
      ? (boards.boards as any).Backyard
      : null;
  state.money = 5;
  state.total_earned = 0;
  state.family = [];
  state.family_slots = 3;
  state.side_pouch = [];
  state.side_pouch_capacity = 3;
  state.auntie_lookup = build_auntie_lookup();
  state.dish_lookup = build_dish_lookup();
  state.auntie_pool = flatten_aunties();
  state.dish_pool = flatten_dishes();
  state.round_index = 1;
  state.target_score = target_for_round(state.round_index);
  state.character = null;
  state.bonus_shop_gold = 0;
  state.starter_peeked = false;
  state.street_failed = false;
  state.last_hand_score = 0;
  state.character_phase = "discard";
  state.phase = "character_select";
  state.screen = "character_select";
  CharacterSelect.selected = 1;
  begin_run_log();
  log_event(`Run start. Money=$${String(state.money)}`);
}

export function update(dt: number): void {
  if (state.score_anim) {
    if (state.score_anim.phase === "slide_in") {
      state.score_anim.timer = state.score_anim.timer + dt;
      if (state.score_anim.timer >= state.score_anim.duration) {
        state.display_round_score = state.score_anim.to;
        state.score_anim = null;
      }
    }
  }
}

export function keypressed(key: string): void {
  if (key === "escape") {
    // No love.event.quit() equivalent; noop or handle at app level
    return;
  }

  if (state.phase === "character_select") {
    const result = CharacterSelect.keypressed(key, state);
    if (result === "start_run") {
      state.phase = "select_hand";
      state.screen = "game";
      start_round();
    }
    return;
  }

  if (key === "i") {
    if (state.phase === "inventory") {
      state.phase = state.inventory_return_phase || "select_hand";
      state.inventory_return_phase = undefined;
    } else {
      state.inventory_return_phase = state.phase;
      state.phase = "inventory";
    }
    return;
  }

  if (key === "v") {
    if (state.phase === "discard_view") {
      state.phase = state.discard_return_phase || "select_hand";
      state.discard_return_phase = undefined;
    } else {
      state.discard_return_phase = state.phase;
      state.discard_view_page = 1;
      state.phase = "discard_view";
    }
    return;
  }

  if (key === "k") {
    if (state.phase === "deck_view") {
      state.phase = state.deck_return_phase || "select_hand";
      state.deck_return_phase = undefined;
    } else {
      state.deck_return_phase = state.phase;
      state.deck_view_page = 1;
      state.phase = "deck_view";
    }
    return;
  }

  if (state.phase === "discard_view") {
    if (key === "n") {
      state.discard_view_page = (state.discard_view_page || 1) + 1;
      return;
    }
    if (key === "p" && (state.discard_view_page || 1) > 1) {
      state.discard_view_page = (state.discard_view_page || 1) - 1;
      return;
    }
    if (key === "b" || key === "v" || key === "return") {
      state.phase = state.discard_return_phase || "select_hand";
      state.discard_return_phase = undefined;
      return;
    }
    return;
  }

  if (state.phase === "deck_view") {
    if (key === "n") {
      state.deck_view_page = (state.deck_view_page || 1) + 1;
      return;
    }
    if (key === "p" && (state.deck_view_page || 1) > 1) {
      state.deck_view_page = (state.deck_view_page || 1) - 1;
      return;
    }
    if (key === "b" || key === "k" || key === "return") {
      state.phase = state.deck_return_phase || "select_hand";
      state.deck_return_phase = undefined;
      return;
    }
    return;
  }

  if (key === "m") {
    if (state.phase === "map") {
      state.phase = state.map_return_phase || "select_hand";
      state.map_return_phase = undefined;
    } else {
      state.map_return_phase = state.phase;
      state.phase = "map";
    }
    return;
  }

  if (state.phase === "map") {
    if (key === "b" || key === "m" || key === "return") {
      state.phase = state.map_return_phase || "select_hand";
      state.map_return_phase = undefined;
    }
    return;
  }

  if (state.phase === "inventory") {
    const index = parseInt(key, 10);
    if (!isNaN(index)) {
      if (index >= 1 && index <= state.family.length) {
        const family_id = state.family[index - 1];
        const item = state.auntie_lookup[family_id];
        if (!item) {
          state.message = "Invalid family member.";
          return;
        }
        if (!String(item.id).match(/^uncle_/)) {
          state.message = `${item.name} is passive.`;
          return;
        }
        state.inventory_use = {
          kind: "uncle",
          item: item,
          requires_card:
            item.id !== "uncle_sage" &&
            item.id !== "uncle_hickory" &&
            item.id !== "uncle_alder",
        };
        reset_selection();
        state.phase = "inventory_target";
        state.message = `Select card(s) for ${item.name}.`;
        return;
      }
      const dish_index = index - state.family.length;
      if (dish_index >= 1 && dish_index <= state.side_pouch.length) {
        const dish = state.side_pouch[dish_index - 1];
        state.inventory_use = {
          kind: "dish",
          item: dish,
          index: dish_index,
          requires_card: true,
        };
        reset_selection();
        state.phase = "inventory_target";
        state.message = `Select card(s) for ${dish.name}.`;
        return;
      }
    }
    if (key === "b") {
      state.phase = state.inventory_return_phase || "select_hand";
      state.inventory_return_phase = undefined;
      return;
    }
    return;
  }

  if (state.phase === "select_hand" || state.phase === "inventory_target") {
    const index = parseInt(key, 10);
    if (!isNaN(index) && index >= 1 && index <= state.player_hand.length) {
      if (state.player_hand[index - 1] && state.player_hand[index - 1].pinned) {
        state.message = "That card is pinned and can't be played.";
        return;
      }
      if (state.selected_cards[index]) {
        state.selected_cards[index] = false;
      } else {
        if (count_selected(state.selected_cards) >= 4) {
          state.message = "Select exactly 4 cards to score.";
        } else {
          state.selected_cards[index] = true;
        }
      }
      return;
    }
    if (key === "r") {
      sort_hand_by_rank(state.player_hand);
      reset_selection();
      return;
    }
    if (key === "s") {
      sort_hand_by_suit(state.player_hand);
      reset_selection();
      return;
    }
    if (key === "h" && state.phase === "select_hand") {
      state.history_return_phase = state.phase;
      state.phase = "hand_history";
      return;
    }
    if (key === "a" && state.phase === "select_hand" && active_can_trigger()) {
      trigger_active();
      return;
    }
    if (state.phase === "inventory_target") {
      if (key === "b") {
        state.inventory_use = null;
        reset_selection();
        state.phase = "inventory";
        return;
      }
      if (key === "return") {
        if (state.inventory_use && state.inventory_use.requires_card) {
          const count = count_selected(state.selected_cards);
          if (count !== 1) {
            state.message = "Select exactly 1 card.";
            return;
          }
        }
        state.phase = "inventory_confirm";
        state.message = "Confirm use? Enter=accept, N=cancel.";
        return;
      }
      if (key === "n") {
        state.inventory_use = null;
        reset_selection();
        state.phase = "inventory";
        return;
      }
      return;
    }
    if (state.phase === "select_hand" && state.active_use) {
      return;
    }
    if (key === "d") {
      if (state.discards_remaining <= 0) {
        state.message = "No discards remaining this round.";
        return;
      }
      const count = count_selected(state.selected_cards);
      if (count === 0) {
        state.message = `Select 1-${String(state.discards_remaining)} cards to discard.`;
        return;
      }
      if (count > state.discards_remaining) {
        state.message = `Only ${String(state.discards_remaining)} discards left this round.`;
        return;
      }
      for (const keyStr of Object.keys(state.selected_cards)) {
        const i = parseInt(keyStr, 10);
        if (state.selected_cards[i]) {
          const card = state.player_hand[i - 1];
          if (card && (card.locked || card.eternal)) {
            state.message = "A selected card can't be discarded.";
            return;
          }
        }
      }
      const indices: number[] = [];
      for (const keyStr of Object.keys(state.selected_cards)) {
        const i = parseInt(keyStr, 10);
        if (state.selected_cards[i]) {
          indices.push(i);
        }
      }
      remove_indices(state.player_hand, indices);
      while (state.player_hand.length < current_hand_size() && state.deck.length > 0) {
        state.player_hand.push(state.deck.pop()!);
      }
      state.discards_remaining = state.discards_remaining - count;
      state.message = null;
      reset_selection();
      return;
    }
    if (key === "return") {
      const count = count_selected(state.selected_cards);
      if (count !== 4) {
        state.message = "Select exactly 4 cards to score.";
        return;
      }
      const picked = collect_selected_cards(state.player_hand, state.selected_cards);
      const picked_indices = collect_selected_indices(state.selected_cards);
      let [total, breakdown, details] = score_with_tea_stain(
        picked,
        state.starter_card,
        state.character
      );
      const score_breakdown = build_score_breakdown(picked, state.starter_card, details);
      if (state.character) {
        const bonus = Characters.applyPassive(state.character, score_breakdown, state);
        if (bonus > 0) {
          (breakdown as any[]).push(`Character bonus: +${String(bonus)}`);
          total = total + bonus;
        }
      }
      const before = state.current_round_score || 0;
      state.current_round_score = state.current_round_score + total;
      state.last_hand_score = total;
      state.score_anim = {
        from: before,
        to: state.current_round_score,
        delta: total,
        phase: "show_delta",
        timer: 0,
        duration: 0.35,
      };
      state.hand_scores.push({ total, breakdown, details });
      state.hand_history.push({ cards: picked });
      state.last_hand = {
        cards: picked,
        total,
        breakdown,
        details,
        indices: picked_indices,
      };
      if (state.objective) {
        state.objective.hands_checked = state.objective.hands_checked + 1;
        const has_fifteen =
          details && details.fifteens && details.fifteens.length > 0;
        if (!has_fifteen) {
          state.objective.failed = true;
        }
        if (state.hands_remaining - 1 === 0 && !state.objective.failed) {
          state.objective.complete = true;
        }
      }
      const removed = remove_indices(state.player_hand, picked_indices);
      for (let i = 0; i < removed.length; i++) {
        state.discard_pile.push(removed[i]);
      }
      while (state.player_hand.length < current_hand_size() && state.deck.length > 0) {
        state.player_hand.push(state.deck.pop()!);
      }
      state.hands_remaining = state.hands_remaining - 1;
      log_event(
        `Hand scored: +${String(total)} (round total ${String(state.current_round_score)})`
      );
      state.phase = "score_hand";
      state.character_phase = "score";
      state.message = null;
      reset_selection();
      return;
    }
  } else if (state.phase === "inventory_confirm") {
    if (key === "n") {
      reset_selection();
      state.phase = "inventory";
      state.message = "Cancelled.";
      return;
    }
    if (key === "return") {
      const target_index = single_selected_index(state.selected_cards);
      const use = state.inventory_use;
      if (!use) {
        state.phase = "inventory";
        return;
      }
      let ok = false;
      let msg = "Invalid inventory use.";
      if (use.kind === "uncle") {
        [ok, msg] = apply_uncle(use.item as AuntieItem, target_index);
      } else if (use.kind === "dish") {
        [ok, msg] = apply_side_dish(use.item as DishItem, target_index);
        if (ok && use.index != null) {
          state.side_pouch.splice(use.index - 1, 1);
        }
      }
      state.inventory_use = null;
      reset_selection();
      state.phase = "select_hand";
      state.character_phase = "discard";
      state.message = msg;
      return;
    }
  } else if (state.phase === "active_target") {
    const index = parseInt(key, 10);
    if (!isNaN(index) && index >= 1 && index <= state.player_hand.length) {
      if (state.selected_cards[index]) {
        state.selected_cards[index] = false;
      } else {
        if (count_selected(state.selected_cards) >= 1) {
          state.message = "Select exactly 1 card.";
        } else {
          state.selected_cards[index] = true;
        }
      }
      return;
    }
    if (key === "return") {
      if (count_selected(state.selected_cards) !== 1) {
        state.message = "Select exactly 1 card.";
        return;
      }
      const target_index = single_selected_index(state.selected_cards);
      if (state.active_use && state.active_use.mode === "swap_one") {
        const card =
          target_index !== null ? state.player_hand[target_index - 1] : null;
        if (card && state.deck.length > 0) {
          state.player_hand[target_index! - 1] = state.deck.pop()!;
          state.deck.push(card);
        }
      } else if (state.active_use && state.active_use.mode === "pick_tea_stain") {
        const card =
          target_index !== null ? state.player_hand[target_index - 1] : null;
        if (card) {
          card.original_rank = card.original_rank || card.rank;
          state.character!.active!.stained_card = {
            suit: card.suit,
            original_rank: card.original_rank,
          };
        }
      }
      state.active_use = null;
      reset_selection();
      state.phase = "select_hand";
      state.character_phase = "discard";
      state.message = "Ability applied.";
      return;
    }
    if (key === "n" || key === "b") {
      state.active_use = null;
      reset_selection();
      state.phase = "select_hand";
      state.character_phase = "discard";
      state.message = "Cancelled.";
      return;
    }
  } else if (state.phase === "score_hand") {
    if (key === "return" || key === "space") {
      if (state.score_anim && state.score_anim.phase === "show_delta") {
        state.score_anim.phase = "slide_in";
        state.score_anim.timer = 0;
      }
      if (
        state.hands_remaining === 0 &&
        state.current_round_score >= state.target_score &&
        !state.round_reward
      ) {
        const [total, breakdown] = calculate_round_reward(
          state.current_round_score,
          state.target_score,
          state.round_index,
          state.discards_remaining,
          state.hands_remaining
        );
        state.round_reward = total;
        state.reward_breakdown = breakdown;
        state.money = state.money + total;
        state.total_earned = state.total_earned + total;
        log_event(
          `Round reward: +${String(total)} (money $${String(state.money)})`
        );
      }
      if (state.hands_remaining > 0) {
        state.phase = "select_hand";
        state.character_phase = "discard";
      } else {
        state.display_round_score = state.current_round_score;
        state.score_anim = null;
        state.street_failed = state.current_round_score < state.target_score;
        state.phase = "round_end";
      }
      return;
    }
    if (key === "h") {
      state.history_return_phase = state.phase;
      state.phase = "hand_history";
      return;
    }
  } else if (state.phase === "hand_history") {
    if (key === "b" || key === "h" || key === "return") {
      state.phase = state.history_return_phase || "select_hand";
      state.history_return_phase = undefined;
      return;
    }
  } else if (state.phase === "shop") {
    const index = parseInt(key, 10);
    if (!isNaN(index)) {
      const stock_family = (state.shop && state.shop.family_stock) || [];
      const stock_dishes = (state.shop && state.shop.dish_stock) || [];
      if (index >= 1 && index <= stock_family.length) {
        const item = stock_family[index - 1];
        if (state.money < item.cost) {
          state.message = "Not enough money.";
          return;
        }
        if (state.family.length >= state.family_slots) {
          state.message = "Family slots full.";
          return;
        }
        const before = state.money;
        state.money = state.money - item.cost;
        state.family.push(item.id);
        state.shop!.family_stock.splice(index - 1, 1);
        state.message = `Hired ${item.name}.`;
        log_event(
          `Purchased family ${item.name} for $${String(item.cost)} (money $${String(before)} -> $${String(state.money)})`
        );
        return;
      }
      const dish_index = index - stock_family.length;
      if (dish_index >= 1 && dish_index <= stock_dishes.length) {
        const item = stock_dishes[dish_index - 1];
        if (state.money < item.cost) {
          state.message = "Not enough money.";
          return;
        }
        if (state.side_pouch.length >= state.side_pouch_capacity) {
          state.message = "Side dish pouch full.";
          return;
        }
        const before = state.money;
        state.money = state.money - item.cost;
        state.side_pouch.push(item);
        state.shop!.dish_stock.splice(dish_index - 1, 1);
        state.message = `Bought ${item.name}.`;
        log_event(
          `Purchased dish ${item.name} for $${String(item.cost)} (money $${String(before)} -> $${String(state.money)})`
        );
        return;
      }
    }
    if (key === "return") {
      start_round();
      return;
    }
  } else if (state.phase === "round_end") {
    if (key === "return") {
      if (state.current_round_score >= state.target_score) {
        if (state.bonus_shop_gold && state.bonus_shop_gold > 0) {
          state.money = state.money + state.bonus_shop_gold;
          log_event(`Character shop bonus: +$${String(state.bonus_shop_gold)}`);
          state.bonus_shop_gold = 0;
        }
        state.round_index = state.round_index + 1;
        state.target_score = target_for_round(state.round_index);
        state.shop = {
          family_stock: pick_random(state.auntie_pool, 3),
          dish_stock: pick_random(state.dish_pool, 3),
        };
        state.phase = "shop";
        state.character_phase = "shop";
      }
      return;
    }
    if (key === "r") {
      state.round_index = 1;
      state.target_score = target_for_round(state.round_index);
      start_round();
      return;
    }
    if (key === "a" && active_can_trigger()) {
      trigger_active();
      return;
    }
  }
}

export function mousepressed(x: number, y: number, button: number): void {
  if (button !== 1) return;

  if (state.phase === "character_select") {
    const result = CharacterSelect.mousepressed(x, y, button, state);
    if (result === "start_run") {
      state.phase = "select_hand";
      state.screen = "game";
      start_round();
    }
    return;
  }

  if (point_in_rect(x, y, inventory_hitbox())) {
    keypressed("i");
    return;
  }

  if (state.phase === "select_hand") {
    const index = hand_index_at(x, y, 30, 300, state.player_hand.length);
    if (index !== null) {
      keypressed(String(index));
      return;
    }
    if (point_in_rect(x, y, enter_button_rect())) {
      keypressed("return");
      return;
    }
    if (point_in_rect(x, y, sort_rank_button_rect())) {
      keypressed("r");
      return;
    }
    if (point_in_rect(x, y, sort_suit_button_rect())) {
      keypressed("s");
      return;
    }
    if (point_in_rect(x, y, history_button_rect())) {
      keypressed("h");
      return;
    }
    if (active_can_trigger() && point_in_rect(x, y, active_button_rect())) {
      trigger_active();
      return;
    }
  } else if (state.phase === "score_hand") {
    if (point_in_rect(x, y, enter_button_rect())) {
      keypressed("return");
      return;
    }
    if (point_in_rect(x, y, history_button_rect())) {
      keypressed("h");
      return;
    }
  } else if (state.phase === "inventory_target") {
    const index = hand_index_at(x, y, 30, 300, state.player_hand.length);
    if (index !== null) {
      keypressed(String(index));
      return;
    }
    if (point_in_rect(x, y, confirm_accept_rect())) {
      keypressed("return");
      return;
    }
    if (point_in_rect(x, y, confirm_cancel_rect())) {
      keypressed("n");
      return;
    }
  } else if (state.phase === "inventory_confirm") {
    if (point_in_rect(x, y, confirm_accept_rect())) {
      keypressed("return");
      return;
    }
    if (point_in_rect(x, y, confirm_cancel_rect())) {
      keypressed("n");
      return;
    }
  } else if (state.phase === "inventory") {
    const family_count = state.family.length;
    for (let i = 1; i <= family_count; i++) {
      if (point_in_rect(x, y, inventory_family_item_rect(i))) {
        keypressed(String(i));
        return;
      }
    }
    for (let i = 1; i <= state.side_pouch.length; i++) {
      if (point_in_rect(x, y, inventory_dish_item_rect(i, family_count))) {
        keypressed(String(i + family_count));
        return;
      }
    }
  } else if (state.phase === "shop") {
    if (!state.shop) return;
    if (point_in_rect(x, y, enter_button_rect())) {
      keypressed("return");
      return;
    }
    const family_count = state.shop.family_stock.length;
    for (let i = 1; i <= family_count; i++) {
      if (point_in_rect(x, y, shop_family_item_rect(i))) {
        keypressed(String(i));
        return;
      }
    }
    const dish_count = state.shop.dish_stock.length;
    for (let i = 1; i <= dish_count; i++) {
      if (point_in_rect(x, y, shop_dish_item_rect(i, family_count))) {
        keypressed(String(i + family_count));
        return;
      }
    }
  } else if (state.phase === "active_target") {
    const index = hand_index_at(x, y, 30, 300, state.player_hand.length);
    if (index !== null) {
      keypressed(String(index));
      return;
    }
    if (point_in_rect(x, y, confirm_accept_rect())) {
      keypressed("return");
      return;
    }
    if (point_in_rect(x, y, confirm_cancel_rect())) {
      keypressed("n");
      return;
    }
  } else if (state.phase === "round_end") {
    if (active_can_trigger() && point_in_rect(x, y, active_button_rect())) {
      trigger_active();
      return;
    }
  } else if (state.phase === "hand_history") {
    if (
      point_in_rect(x, y, history_button_rect()) ||
      point_in_rect(x, y, enter_button_rect())
    ) {
      keypressed("h");
      return;
    }
  }
}

export function draw(ctx: CanvasRenderingContext2D): void {
  if (state.phase === "character_select") {
    CharacterSelect.draw(ctx);
    return;
  }
  if (state.phase === "select_hand") {
    state.character_phase = "discard";
  } else if (state.phase === "score_hand" || state.phase === "round_end") {
    state.character_phase = "score";
  } else if (state.phase === "shop") {
    state.character_phase = "shop";
  }

  draw_top_bar(ctx);
  draw_starter(ctx);
  draw_round_score_display(ctx);
  draw_board_panel(ctx);
  draw_family_panel(ctx);
  setColor(ctx, 1, 1, 1);

  if (state.character) {
    const screen_w = 1200;
    const screen_h = 800;
    const [card_w, card_h] = CharacterSelect.card_dimensions();
    const scale = 1;
    const padding = 20;
    const x = screen_w - card_w * scale - padding;
    const y = screen_h - card_h * scale - padding;
    CharacterSelect.draw_card(ctx, state.character, x, y, scale, false);
  }

  if (state.phase === "select_hand") {
    setColor(ctx, 1, 1, 1);
    ctx.fillText(
      `Select 4 cards. Enter=score, D=discard (1-${String(state.discards_remaining)}), I=inventory use, R=rank sort, S=suit sort.`,
      30,
      260 + 14
    );
    ui.draw_hand(ctx, state.player_hand, 30, 300, state.selected_cards);
    ctx.lineWidth = 1;
    roundedRect(ctx, 30, 610, 90, 28, 6);
    ctx.stroke();
    ctx.fillText("Enter", 50, 615 + 14);
    const rank_button = sort_rank_button_rect();
    const suit_button = sort_suit_button_rect();
    roundedRect(ctx, rank_button.x, rank_button.y, rank_button.w, rank_button.h, 6);
    ctx.stroke();
    ctx.fillText("Rank sort", rank_button.x + 8, rank_button.y + 5 + 14);
    roundedRect(ctx, suit_button.x, suit_button.y, suit_button.w, suit_button.h, 6);
    ctx.stroke();
    ctx.fillText("Suit sort", suit_button.x + 8, suit_button.y + 5 + 14);
    const history = history_button_rect();
    roundedRect(ctx, history.x, history.y, history.w, history.h, 6);
    ctx.stroke();
    ctx.fillText("History", history.x + 12, history.y + 5 + 14);
    if (active_can_trigger()) {
      const active = active_button_rect();
      roundedRect(ctx, active.x, active.y, active.w, active.h, 6);
      ctx.stroke();
      ctx.fillText(state.character!.active!.name, active.x + 8, active.y + 5 + 14);
    }
    if (state.objective) {
      const tally = state.objective.complete ? "1/1" : "0/1";
      ctx.fillText(
        `Objective: ${state.objective.label} (${tally})`,
        30,
        230 + 14
      );
    }
  } else if (state.phase === "inventory_target") {
    setColor(ctx, 1, 1, 1);
    ctx.fillText("Select target card(s). Enter to confirm, N to cancel.", 30, 260 + 14);
    ui.draw_hand(ctx, state.player_hand, 30, 300, state.selected_cards);
    const accept = confirm_accept_rect();
    const cancel = confirm_cancel_rect();
    ctx.lineWidth = 1;
    roundedRect(ctx, accept.x, accept.y, accept.w, accept.h, 6);
    ctx.stroke();
    ctx.fillText("Accept", accept.x + 12, accept.y + 5 + 14);
    roundedRect(ctx, cancel.x, cancel.y, cancel.w, cancel.h, 6);
    ctx.stroke();
    ctx.fillText("Cancel", cancel.x + 12, cancel.y + 5 + 14);
  } else if (state.phase === "inventory_confirm") {
    setColor(ctx, 1, 1, 1);
    ctx.fillText("Confirm use? Enter=accept, N=cancel.", 30, 260 + 14);
    const accept = confirm_accept_rect();
    const cancel = confirm_cancel_rect();
    ctx.lineWidth = 1;
    roundedRect(ctx, accept.x, accept.y, accept.w, accept.h, 6);
    ctx.stroke();
    ctx.fillText("Accept", accept.x + 12, accept.y + 5 + 14);
    roundedRect(ctx, cancel.x, cancel.y, cancel.w, cancel.h, 6);
    ctx.stroke();
    ctx.fillText("Cancel", cancel.x + 12, cancel.y + 5 + 14);
  } else if (state.phase === "active_target") {
    setColor(ctx, 1, 1, 1);
    ctx.fillText(state.message || "Select target card.", 30, 260 + 14);
    ui.draw_hand(ctx, state.player_hand, 30, 300, state.selected_cards);
    const accept = confirm_accept_rect();
    const cancel = confirm_cancel_rect();
    ctx.lineWidth = 1;
    roundedRect(ctx, accept.x, accept.y, accept.w, accept.h, 6);
    ctx.stroke();
    ctx.fillText("Accept", accept.x + 12, accept.y + 5 + 14);
    roundedRect(ctx, cancel.x, cancel.y, cancel.w, cancel.h, 6);
    ctx.stroke();
    ctx.fillText("Cancel", cancel.x + 12, cancel.y + 5 + 14);
  } else if (state.phase === "score_hand") {
    setColor(ctx, 1, 1, 1);
    ctx.fillText("Hand scored. Press Enter to continue.", 30, 260 + 14);
    ctx.lineWidth = 1;
    roundedRect(ctx, 30, 610, 90, 28, 6);
    ctx.stroke();
    ctx.fillText("Enter", 50, 615 + 14);
    const history = history_button_rect();
    roundedRect(ctx, history.x, history.y, history.w, history.h, 6);
    ctx.stroke();
    ctx.fillText("History", history.x + 12, history.y + 5 + 14);
    if (state.objective) {
      const tally = state.objective.complete ? "1/1" : "0/1";
      ctx.fillText(
        `Objective: ${state.objective.label} (${tally})`,
        30,
        230 + 14
      );
    }
    if (state.last_hand) {
      ui.draw_cards_row(ctx, state.last_hand.cards, 30, 300);
      const entries = build_combo_entries(state.last_hand.details);
      entries.push({ label: `Total: ${String(state.last_hand.total)}` });
      ui.draw_combo_entries(ctx, entries, 30, 430);
    }
  } else if (state.phase === "round_end") {
    setColor(ctx, 1, 1, 1);
    ctx.fillText("Round complete.", 30, 260 + 14);
    ctx.fillText(`Total score: ${String(state.current_round_score)}`, 30, 290 + 14);
    ctx.fillText(`Target: ${String(state.target_score)}`, 30, 320 + 14);
    if (state.objective) {
      const tally = state.objective.complete ? "1/1" : "0/1";
      ctx.fillText(
        `Objective: ${state.objective.label} (${tally})`,
        30,
        350 + 14
      );
    }
    const next_bonus_1 = Math.floor(state.target_score * 1.1 + 0.5);
    const next_bonus_2 = Math.floor(state.target_score * 1.2 + 0.5);
    const next_bonus_3 = Math.floor(state.target_score * 1.3 + 0.5);
    ctx.fillText(
      `Bonus thresholds: ${String(next_bonus_1)} (+$1), ${String(next_bonus_2)} (+$2), ${String(next_bonus_3)} (+$3)`,
      30,
      380 + 14
    );
    if (state.current_round_score >= state.target_score) {
      ctx.fillText("Success! Press Enter to open the shop.", 30, 360 + 14);
      if (!state.round_reward) {
        const [total, breakdown] = calculate_round_reward(
          state.current_round_score,
          state.target_score,
          state.round_index,
          state.discards_remaining,
          state.hands_remaining
        );
        state.reward_breakdown = breakdown;
        state.round_reward = total;
      }
      if (state.reward_breakdown) {
        ctx.fillText(`Base: +$${String(state.reward_breakdown.base)}`, 30, 410 + 14);
        ctx.fillText(
          `Performance: +$${String(state.reward_breakdown.performance)}`,
          30,
          430 + 14
        );
        ctx.fillText(
          `Perfect (no discards): +$${String(state.reward_breakdown.perfect)}`,
          30,
          450 + 14
        );
        ctx.fillText(
          `Hands saved: +$${String(state.reward_breakdown.hands_saved)}`,
          30,
          470 + 14
        );
        ctx.fillText(
          `Total earned this round: +$${String(state.round_reward || 0)}`,
          30,
          490 + 14
        );
        ctx.fillText(
          `Total earned run: $${String(state.total_earned || 0)}`,
          30,
          510 + 14
        );
      }
    } else {
      ctx.fillText("Failed. Press R to restart.", 30, 360 + 14);
      if (state.character && state.character.death_text) {
        ui.draw_text_block(ctx, [state.character.death_text], 30, 390);
      }
      if (active_can_trigger()) {
        const active = active_button_rect();
        ctx.lineWidth = 1;
        roundedRect(ctx, active.x, active.y, active.w, active.h, 6);
        ctx.stroke();
        ctx.fillText(state.character!.active!.name, active.x + 8, active.y + 5 + 14);
        ctx.fillText(
          "Press A or click to use ability.",
          active.x + active.w + 12,
          active.y + 5 + 14
        );
      }
    }
  } else if (state.phase === "shop") {
    setColor(ctx, 1, 1, 1);
    ctx.fillText(
      `Shop - Money: $${String(state.money)} (Enter to continue)`,
      30,
      260 + 14
    );
    ctx.fillText("Family for hire:", 30, 290 + 14);
    let y = 320;
    for (let i = 0; i < state.shop!.family_stock.length; i++) {
      const item = state.shop!.family_stock[i];
      ctx.fillText(`${String(i + 1)}) ${item.name} - $${String(item.cost)}`, 30, y + 14);
      ctx.fillText(item.effect, 220, y + 14);
      y = y + 18;
    }
    y = y + 18;
    ctx.fillText("Side dishes:", 30, y + 14);
    y = y + 30;
    for (let i = 0; i < state.shop!.dish_stock.length; i++) {
      const item = state.shop!.dish_stock[i];
      const index = i + 1 + state.shop!.family_stock.length;
      ctx.fillText(`${String(index)}) ${item.name} - $${String(item.cost)}`, 30, y + 14);
      ctx.fillText(item.effect, 220, y + 14);
      y = y + 18;
    }
    ctx.lineWidth = 1;
    roundedRect(ctx, 30, 610, 90, 28, 6);
    ctx.stroke();
    ctx.fillText("Enter", 50, 615 + 14);
  } else if (state.phase === "inventory") {
    setColor(ctx, 1, 1, 1);
    ctx.fillText("Inventory (press I or B to return)", 30, 260 + 14);
    ctx.fillText(
      `Family (${String(state.family.length)}/${String(state.family_slots)}):`,
      30,
      290 + 14
    );
    let y = 320;
    for (let i = 0; i < state.family.length; i++) {
      const item = state.auntie_lookup[state.family[i]];
      if (item) {
        ctx.fillText(
          `${String(i + 1)}) ${item.name} - ${item.effect}`,
          30,
          y + 14
        );
        y = y + 18;
      }
    }
    y = y + 18;
    ctx.fillText(
      `Side dishes (${String(state.side_pouch.length)}/${String(state.side_pouch_capacity)}):`,
      30,
      y + 14
    );
    y = y + 30;
    for (let i = 0; i < state.side_pouch.length; i++) {
      const item = state.side_pouch[i];
      const index = i + 1 + state.family.length;
      ctx.fillText(
        `${String(index)}) ${item.name} - ${item.effect}`,
        30,
        y + 14
      );
      y = y + 18;
    }
  } else if (state.phase === "map") {
    setColor(ctx, 1, 1, 1);
    const board = state.board;
    if (board) {
      ctx.fillText(`Board Map - ${board.name}`, 30, 240 + 14);
      let y = 270;
      for (let i = 0; i < board.streets.length; i++) {
        const street = board.streets[i];
        let prefix = "○ ";
        if (i + 1 < state.round_index) {
          prefix = "✓ ";
        } else if (i + 1 === state.round_index) {
          prefix = "► ";
        }
        ctx.fillText(
          `${prefix}Street ${String(street.id)}: ${street.name}`,
          30,
          y + 14
        );
        ctx.fillText(`Cond: ${street.condition}`, 320, y + 14);
        y = y + 18;
      }
      ctx.fillText("Press M/B/Enter to close.", 30, y + 20 + 14);
    }
  } else if (state.phase === "discard_view") {
    setColor(ctx, 1, 1, 1);
    ctx.fillText(`Discard pile (${String(state.discard_pile.length)})`, 30, 260 + 14);
    const page = state.discard_view_page || 1;
    const per_page = 9;
    const [start_index, end_index] = draw_card_page(
      ctx,
      state.discard_pile,
      page,
      per_page,
      30,
      300
    );
    ctx.fillText(
      `Showing ${String(start_index)}-${String(end_index)} (N/P to page, B to close)`,
      30,
      430 + 14
    );
  } else if (state.phase === "deck_view") {
    setColor(ctx, 1, 1, 1);
    ctx.fillText(`Deck (${String(state.deck.length)})`, 30, 260 + 14);
    const page = state.deck_view_page || 1;
    const per_page = 9;
    const [start_index, end_index] = draw_card_page(
      ctx,
      state.deck,
      page,
      per_page,
      30,
      300
    );
    ctx.fillText(
      `Showing ${String(start_index)}-${String(end_index)} (N/P to page, B to close)`,
      30,
      430 + 14
    );
  } else if (state.phase === "hand_history") {
    setColor(ctx, 1, 1, 1);
    ctx.fillText("Hand History (this round)", 30, 260 + 14);
    ctx.fillText("Press H/B/Enter to return.", 30, 280 + 14);
    let y = 320;
    for (let i = 0; i < state.hand_history.length; i++) {
      ctx.fillText(`Hand ${String(i + 1)}:`, 30, y + 14);
      ui.draw_cards_row(ctx, state.hand_history[i].cards, 120, y - 10);
      y = y + 80;
    }
  }

  if (state.message) {
    setColor(ctx, 1, 1, 1);
    ctx.fillText(state.message, 30, 620 + 14);
  }
}
