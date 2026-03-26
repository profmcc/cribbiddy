import { Character, characterList } from "./characters.js";

const CARD_W = 230;
const CARD_H = 320;
const PADDING = 24;

const CANVAS_W = 1200;
const CANVAS_H = 800;

// ---------------------------------------------------------------------------
// Helpers (internal)
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

function cardBounds(
  index: number,
  cardW: number,
  cardH: number,
  padding: number,
  startX: number,
  y: number
): { x: number; y: number; w: number; h: number } {
  const x = startX + (index - 1) * (cardW + padding);
  return { x, y, w: cardW, h: cardH };
}

// ---------------------------------------------------------------------------
// Module state
// ---------------------------------------------------------------------------

export let selected = 1;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

export function drawCard(
  ctx: CanvasRenderingContext2D,
  char: Character,
  x: number,
  y: number,
  scale: number,
  isSelected: boolean
): void {
  const s = scale ?? 1;
  const w = CARD_W * s;
  const h = CARD_H * s;
  const inset = 10 * s;
  const fontSize = Math.round(16 * s);

  ctx.font = `${fontSize}px monospace`;

  // Filled card background
  const alpha = isSelected ? 1.0 : 0.8;
  setColor(ctx, char.color[0], char.color[1], char.color[2], alpha);
  roundRect(ctx, x, y, w, h, 12 * s);
  ctx.fill();

  // Border
  setColor(ctx, 0.43, 0.37, 0.31);
  ctx.lineWidth = isSelected ? 3 : 1;
  roundRect(ctx, x, y, w, h, 12 * s);
  ctx.stroke();

  // Name
  setColor(ctx, 0.25, 0.18, 0.12);
  printAligned(ctx, char.name, x + inset, y + 12 * s + fontSize, w - inset * 2, "center");

  // Visiting subtitle
  setColor(ctx, 0.45, 0.35, 0.28);
  printAligned(ctx, char.visiting, x + inset, y + 35 * s + fontSize, w - inset * 2, "center");

  // Passive ability header
  setColor(ctx, 0.25, 0.18, 0.12);
  printAligned(ctx, "\u2746 " + char.passive.name, x + inset, y + 80 * s + fontSize, w - inset * 2, "left");

  // Passive ability description
  setColor(ctx, 0.45, 0.35, 0.28);
  printAligned(ctx, char.passive.description, x + inset, y + 100 * s + fontSize, w - inset * 2, "left");

  // Active ability header
  setColor(ctx, 0.25, 0.18, 0.12);
  printAligned(ctx, "\u26A1 " + char.active.name, x + inset, y + 160 * s + fontSize, w - inset * 2, "left");

  // Active ability description
  setColor(ctx, 0.45, 0.35, 0.28);
  printAligned(ctx, char.active.description, x + inset, y + 180 * s + fontSize, w - inset * 2, "left");
}

export function draw(ctx: CanvasRenderingContext2D): void {
  const chars = characterList;
  const cardW = CARD_W;
  const cardH = CARD_H;
  const padding = PADDING;
  const totalW = chars.length * (cardW + padding) - padding;
  const startX = (CANVAS_W - totalW) / 2;
  const y = CANVAS_H / 2 - cardH / 2;

  for (let i = 0; i < chars.length; i++) {
    const char = chars[i];
    const x = startX + i * (cardW + padding);
    const isSelected = i + 1 === selected;
    drawCard(ctx, char, x, y, 1, isSelected);
  }

  setColor(ctx, 0.43, 0.37, 0.31);
  ctx.font = "16px monospace";
  printAligned(
    ctx,
    "\u2190 \u2192 to browse   ENTER to choose",
    0,
    y + cardH + 30 + 16,
    CANVAS_W,
    "center"
  );
}

export type GameState = {
  character?: Character;
  [key: string]: unknown;
};

export function keypressed(
  key: string,
  gameState: GameState
): string | null {
  if (key === "ArrowLeft" || key === "left") {
    selected = Math.max(1, selected - 1);
  } else if (key === "ArrowRight" || key === "right") {
    selected = Math.min(characterList.length, selected + 1);
  } else if (key === "Enter" || key === "return" || key === " " || key === "space") {
    gameState.character = characterList[selected - 1];
    return "start_run";
  }
  return null;
}

export function mousepressed(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  button: number,
  gameState: GameState
): string | null {
  if (button !== 1) {
    return null;
  }
  const chars = characterList;
  const cardW = CARD_W;
  const cardH = CARD_H;
  const padding = PADDING;
  const totalW = chars.length * (cardW + padding) - padding;
  const startX = (CANVAS_W - totalW) / 2;
  const topY = CANVAS_H / 2 - cardH / 2;

  for (let i = 1; i <= chars.length; i++) {
    const bounds = cardBounds(i, cardW, cardH, padding, startX, topY);
    if (
      x >= bounds.x &&
      x <= bounds.x + bounds.w &&
      y >= bounds.y &&
      y <= bounds.y + bounds.h
    ) {
      selected = i;
      gameState.character = characterList[selected - 1];
      return "start_run";
    }
  }
  return null;
}
