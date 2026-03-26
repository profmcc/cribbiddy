import * as game from "./game.ts";

const canvas = document.getElementById("game") as HTMLCanvasElement;
canvas.width = 1200;
canvas.height = 800;

const ctx = canvas.getContext("2d")!;
ctx.font = "16px monospace";

game.load(ctx);

let lastTime = 0;

function loop(timestamp: number) {
  const dt = Math.min((timestamp - lastTime) / 1000, 0.1);
  lastTime = timestamp;

  ctx.fillStyle = "#1e1e28";
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  game.update(dt);
  game.draw(ctx);

  requestAnimationFrame(loop);
}

requestAnimationFrame((t) => {
  lastTime = t;
  loop(t);
});

window.addEventListener("keydown", (e) => {
  // Prevent browser shortcuts interfering with game keys
  if (["ArrowLeft","ArrowRight","ArrowUp","ArrowDown"," "].includes(e.key)) {
    e.preventDefault();
  }
  game.keypressed(e.key);
});

canvas.addEventListener("mousedown", (e) => {
  const rect = canvas.getBoundingClientRect();
  const scaleX = canvas.width / rect.width;
  const scaleY = canvas.height / rect.height;
  const x = (e.clientX - rect.left) * scaleX;
  const y = (e.clientY - rect.top) * scaleY;
  game.mousepressed(x, y, e.button + 1);
});
