-- characters.lua
-- Defines all playable starting characters and their abilities

local Characters = {}

Characters.list = {
  {
    id = "benny",
    name = "Benny Biscuit",
    visiting = "Auntie Clover the Baker",
    description = "You've played cribbage with Auntie Clover a hundred times.",
    color = { 0.85, 0.75, 0.80 },

    passive = {
      name = "Extra Cookie",
      description = "Pairs always score +1 bonus peg.",
      onScore = function(self, score_breakdown, game_state)
        local bonus = 0
        for _, entry in ipairs(score_breakdown) do
          if entry.type == "pair" or entry.type == "triple" or entry.type == "quad" then
            bonus = bonus + 1
          end
        end
        return bonus
      end,
    },

    active = {
      name = "Save Me a Slice",
      description = "Once per run: if you fail a street, score your hand a second time.",
      uses_remaining = 1,
      canTrigger = function(self, game_state)
        return self.uses_remaining > 0 and game_state.street_failed == true
      end,
      onActivate = function(self, game_state)
        self.uses_remaining = self.uses_remaining - 1
        local bonus = game_state.last_hand_score or 0
        return bonus
      end,
    },

    death_text = "Auntie Clover shuffles over in her slippers and drapes a crocheted throw over you. She turns off the lamp and whispers 'you were so close, buttercup.' A small glass of water appears on the side table.",
  },

  {
    id = "marigold",
    name = "Marigold Mosswick",
    visiting = "Uncle Barnaby the Woodcarver",
    description = "You don't care about fifteens. You care about sequences.",
    color = { 0.72, 0.80, 0.68 },

    passive = {
      name = "Grain of the Wood",
      description = "Runs of 3 or more score +1 bonus peg.",
      onScore = function(self, score_breakdown, game_state)
        local bonus = 0
        for _, entry in ipairs(score_breakdown) do
          if entry.type == "run" and entry.length >= 3 then
            bonus = bonus + 1
          end
        end
        return bonus
      end,
    },

    active = {
      name = "One More Pass",
      description = "Once per street: after seeing the starter card, swap one card in your hand with the top of your deck.",
      uses_remaining = 0,
      canTrigger = function(self, game_state)
        return self.uses_remaining > 0 and game_state.phase == "discard"
      end,
      onActivate = function(self, game_state)
        self.uses_remaining = self.uses_remaining - 1
        return "swap_one"
      end,
      onStreetStart = function(self)
        self.uses_remaining = 1
      end,
    },

    death_text = "Uncle Barnaby sets down his carving. He puts a big warm hand on your head and says 'good effort, sprout.' He covers you up. There's a glass of water and a small wood chip on the table — he was carving while you played.",
  },

  {
    id = "pip",
    name = "Pip Tanglewood",
    visiting = "Auntie Vesper the Night Owl",
    description = "You're not sure you even know the rules. You know vibes.",
    color = { 0.78, 0.72, 0.85 },

    passive = {
      name = "Lucky Dip",
      description = "Nobs scores +2 pegs instead of +1.",
      onScore = function(self, score_breakdown, game_state)
        local bonus = 0
        for _, entry in ipairs(score_breakdown) do
          if entry.type == "nobs" then
            bonus = bonus + 2
          end
        end
        return bonus
      end,
    },

    active = {
      name = "Tea Stain",
      description = "Once per run: choose a card. A tea stain permanently marks it — it counts as any rank you need each hand.",
      uses_remaining = 1,
      stained_card = nil,
      canTrigger = function(self, game_state)
        return self.uses_remaining > 0
      end,
      onActivate = function(self, game_state)
        self.uses_remaining = self.uses_remaining - 1
        return "pick_tea_stain"
      end,
      getStainedCardRank = function(self, card, needed_rank)
        if self.stained_card
          and card.suit == self.stained_card.suit
          and card.original_rank == self.stained_card.original_rank
        then
          return needed_rank
        end
        return card.rank
      end,
    },

    death_text = "Auntie Vesper is still awake when you drift off. She wraps you in her big quilted cardigan and leaves a note on the water glass: 'better luck next time, little chaos gremlin 🦊'",
  },

  {
    id = "rosette",
    name = "Rosette Puddingstone",
    visiting = "Uncle Pemberton the Retired Accountant",
    description = "Fifteen-two, fifteen-four, fifteen-six — you hear it in your dreams.",
    color = { 0.91, 0.87, 0.70 },

    passive = {
      name = "Perfect Accounting",
      description = "Any hand scoring 8+ pegs earns +$1 in the shop.",
      onScore = function(self, score_breakdown, game_state)
        local total = 0
        for _, entry in ipairs(score_breakdown) do
          total = total + (entry.points or 0)
        end
        if total >= 8 then
          game_state.bonus_shop_gold = (game_state.bonus_shop_gold or 0) + 1
        end
        return 0
      end,
    },

    active = {
      name = "Run the Numbers",
      description = "Once per street: peek at the next starter card before discarding.",
      uses_remaining = 0,
      canTrigger = function(self, game_state)
        return self.uses_remaining > 0 and game_state.phase == "discard" and game_state.starter_peeked == false
      end,
      onActivate = function(self, game_state)
        self.uses_remaining = self.uses_remaining - 1
        game_state.starter_peeked = true
        return "peek_starter"
      end,
      onStreetStart = function(self, game_state)
        self.uses_remaining = 1
        game_state.starter_peeked = false
      end,
    },

    death_text = "Uncle Pemberton closes his ledger, gives a small nod, and says 'statistically sound effort.' He tucks you in with military precision. The water glass is placed at exactly a 90-degree angle from the corner of the table.",
  },
}

function Characters.getById(id)
  for _, char in ipairs(Characters.list) do
    if char.id == id then
      return char
    end
  end
  return nil
end

function Characters.onStreetStart(character, game_state)
  if character.active.onStreetStart then
    character.active.onStreetStart(character.active, game_state)
  end
end

function Characters.applyPassive(character, score_breakdown, game_state)
  if character.passive.onScore then
    return character.passive.onScore(character.passive, score_breakdown, game_state)
  end
  return 0
end

return Characters
