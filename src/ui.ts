import { cardLabel } from "./cards.js";

export type Card = {
  rank: number;
  suit: number;
  hidden?: boolean;
  vined?: boolean;
  enhancement?: string;
};

const CARD_W = 70;
const CARD_H = 100;
const GAP = 10;
const STACK_OFFSET = 18;
const STARTER_X = 30;
const STARTER_Y = 490;

const CANVAS_W = 1200;
const CANVAS_H = 800;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function setColor(
  ctx: CanvasRenderingContext2D,
  r: number,
  g: number,
  b: number,
  a: number = 1
): void {
  const css = `rgba(${r * 255 | 0}, ${g * 255 | 0}, ${b * 255 | 0}, ${a})`;
  ctx.fillStyle = css;
  ctx.strokeStyle = css;
}

function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number
): void {
  const radius = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.lineTo(x + w - radius, y);
  ctx.arcTo(x + w, y, x + w, y + radius, radius);
  ctx.lineTo(x + w, y + h - radius);
  ctx.arcTo(x + w, y + h, x + w - radius, y + h, radius);
  ctx.lineTo(x + radius, y + h);
  ctx.arcTo(x, y + h, x, y + h - radius, radius);
  ctx.lineTo(x, y + radius);
  ctx.arcTo(x, y, x + radius, y, radius);
  ctx.closePath();
}

function printAligned(
  ctx: CanvasRenderingContext2D,
  text: string,
  x: number,
  y: number,
  w: number,
  align: "left" | "center" | "right"
): void {
  const measured = ctx.measureText(text).width;
  let drawX = x;
  if (align === "center") {
    drawX = x + (w - measured) / 2;
  } else if (align === "right") {
    drawX = x + w - measured;
  }
  ctx.fillText(text, drawX, y);
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

export function setFont(ctx: CanvasRenderingContext2D): void {
  ctx.font = "16px monospace";
}

export function drawCard(
  ctx: CanvasRenderingContext2D,
  card: Card,
  x: number,
  y: number,
  highlighted: boolean
): void {
  if (highlighted) {
    setColor(ctx, 0.3, 0.6, 0.9, 0.4);
    roundRect(ctx, x, y, CARD_W, CARD_H, 6);
    ctx.fill();
  }

  if (card.vined) {
    setColor(ctx, 0.5, 0.6, 0.5);
  } else {
    setColor(ctx, 1, 1, 1);
  }
  roundRect(ctx, x, y, CARD_W, CARD_H, 6);
  ctx.stroke();

  if (card.hidden) {
    ctx.fillText("??", x + 10, y + 10 + 14); // offset by ~font ascent
  } else {
    ctx.fillText(cardLabel(card), x + 10, y + 10 + 14);
  }
}

export function drawFaceUpCard(
  ctx: CanvasRenderingContext2D,
  card: Card,
  x: number,
  y: number
): void {
  drawCard(ctx, card, x, y, false);
}

export function drawHand(
  ctx: CanvasRenderingContext2D,
  hand: Card[],
  x: number,
  y: number,
  selected: boolean[] | null
): void {
  for (let i = 0; i < hand.length; i++) {
    const card = hand[i];
    const cardX = x + i * (CARD_W + GAP);
    const isSelected = selected ? selected[i] : false;
    drawCard(ctx, card, cardX, y, isSelected);
    setColor(ctx, 1, 1, 1);
    ctx.fillText(String(i + 1), cardX + 30, y + CARD_H + 6 + 14);
  }
}

export function drawCardsRow(
  ctx: CanvasRenderingContext2D,
  cards: Card[],
  x: number,
  y: number
): void {
  for (let i = 0; i < cards.length; i++) {
    const cardX = x + i * (CARD_W + GAP);
    drawCard(ctx, cards[i], cardX, y, false);
  }
}

export type ComboEntry = {
  label: string;
  cards?: Card[];
};

export function drawComboEntries(
  ctx: CanvasRenderingContext2D,
  entries: ComboEntry[],
  x: number,
  y: number
): number {
  let cursor = y;
  const rowHeight = CARD_H + 10;
  for (const entry of entries) {
    ctx.fillText(entry.label, x, cursor + 14);
    if (entry.cards && entry.cards.length > 0) {
      drawCardsRow(ctx, entry.cards, x + 140, cursor - 10);
      cursor += rowHeight;
    } else {
      cursor += 18;
    }
  }
  return cursor;
}

export function drawTextBlock(
  ctx: CanvasRenderingContext2D,
  lines: string[],
  x: number,
  y: number
): void {
  for (let i = 0; i < lines.length; i++) {
    ctx.fillText(lines[i], x, y + i * 18 + 14);
  }
}

export type ScoreboardState = {
  level: number | string;
  dealer: string;
  player_score: number;
  ai_score: number;
};

export function drawScoreboard(
  ctx: CanvasRenderingContext2D,
  state: ScoreboardState
): void {
  const lines = [
    "Level: " + String(state.level),
    "Goal: 121",
    "Dealer: " + state.dealer,
    "Player: " + String(state.player_score),
    "AI: " + String(state.ai_score),
  ];
  drawTextBlock(ctx, lines, 30, 20);
}

export function drawPhase(
  ctx: CanvasRenderingContext2D,
  phase: string,
  x: number,
  y: number
): void {
  ctx.fillText("Phase: " + phase, x, y + 14);
}

export function drawPegStack(
  ctx: CanvasRenderingContext2D,
  stack: Card[],
  x: number,
  y: number
): void {
  for (let i = 0; i < stack.length; i++) {
    const cardX = x + i * 40;
    drawCard(ctx, stack[i], cardX, y, false);
  }
}

// ---------------------------------------------------------------------------
// Internal helper – face-down card
// ---------------------------------------------------------------------------

function drawFaceDownCard(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  alpha: number
): void {
  setColor(ctx, 0.12, 0.12, 0.18, alpha);
  roundRect(ctx, x, y, CARD_W, CARD_H, 6);
  ctx.fill();
  setColor(ctx, 1, 1, 1, alpha);
  roundRect(ctx, x, y, CARD_W, CARD_H, 6);
  ctx.stroke();
}

export type CutStack = {
  visual_size: number;
  selected?: number;
  status: string;
  fade_left?: number;
  fade_right?: number;
  drop_offset?: number;
  slide_progress?: number;
  target_x?: number;
  target_y?: number;
  pointer: number;
  card: Card;
};

function cardAlphaForIndex(cut: CutStack, index: number): number {
  if (cut.selected !== undefined && index === cut.selected) {
    if (
      cut.status === "reveal" ||
      cut.status === "clear_right" ||
      cut.status === "slide"
    ) {
      return 0;
    }
  }
  if (cut.status === "aim") {
    return 1;
  }
  if (cut.selected === undefined) {
    return 1;
  }
  if (index < cut.selected) {
    if (cut.status === "clear_left") {
      return cut.fade_left ?? 0;
    }
    return 0;
  }
  if (index > cut.selected) {
    if (cut.status === "clear_right") {
      return cut.fade_right ?? 0;
    }
    if (cut.status === "drop") {
      return 1;
    }
    if (cut.status === "clear_left") {
      return 1;
    }
    return 0;
  }
  return 1;
}

export function drawCutStack(
  ctx: CanvasRenderingContext2D,
  cut: CutStack,
  x: number,
  y: number
): void {
  for (let i = 1; i <= cut.visual_size; i++) {
    const alpha = cardAlphaForIndex(cut, i);
    if (alpha > 0) {
      const xOffset = (i - 1) * STACK_OFFSET;
      let yOffset = 0;
      if (
        cut.selected !== undefined &&
        i === cut.selected &&
        cut.status === "drop"
      ) {
        yOffset += cut.drop_offset ?? 0;
      }
      drawFaceDownCard(ctx, x + xOffset, y + yOffset, alpha);
    }
  }

  if (
    cut.selected !== undefined &&
    (cut.status === "reveal" || cut.status === "clear_right")
  ) {
    const baseX = x + (cut.selected - 1) * STACK_OFFSET;
    const baseY = y + (cut.drop_offset ?? 0);
    drawFaceUpCard(ctx, cut.card, baseX, baseY);
  } else if (cut.selected !== undefined && cut.status === "slide") {
    const baseX = x + (cut.selected - 1) * STACK_OFFSET;
    const baseY = y + (cut.drop_offset ?? 0);
    const t = cut.slide_progress ?? 0;
    const targetX = cut.target_x ?? STARTER_X;
    const targetY = cut.target_y ?? STARTER_Y;
    const drawX = baseX + (targetX - baseX) * t;
    const drawY = baseY + (targetY - baseY) * t;
    drawFaceUpCard(ctx, cut.card, drawX, drawY);
  }

  if (cut.status === "aim") {
    const pointerX = x + (cut.pointer - 1) * STACK_OFFSET + CARD_W / 2;
    setColor(ctx, 1, 0.8, 0.2, 0.9);
    ctx.beginPath();
    ctx.moveTo(pointerX - 8, y - 12);
    ctx.lineTo(pointerX + 8, y - 12);
    ctx.lineTo(pointerX, y);
    ctx.closePath();
    ctx.fill();
    setColor(ctx, 1, 1, 1, 1);
  }
}

export function cardDimensions(): { w: number; h: number; gap: number } {
  return { w: CARD_W, h: CARD_H, gap: GAP };
}

export function starterPosition(): { x: number; y: number } {
  return { x: STARTER_X, y: STARTER_Y };
}
