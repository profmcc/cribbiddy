local M = {}

M.BLIND_TYPE = {
  SMALL = 1,
  BIG = 2,
  BOSS_APPROACH = 3,
  BOSS = 4,
}

M.QUOTA_CONFIG = {
  base = {
    [M.BLIND_TYPE.SMALL] = { quota = 25, hands = 4, phase_required = false },
    [M.BLIND_TYPE.BIG] = { quota = 40, hands = 4, phase_required = false },
    [M.BLIND_TYPE.BOSS_APPROACH] = { quota = 55, hands = 3, phase_required = true },
    [M.BLIND_TYPE.BOSS] = { quota = 75, hands = 3, phase_required = true },
  },
  ante_scaling = {
    { ante = 1, quota_mod = 0, hand_mod = 0 },
    { ante = 2, quota_mod = 5, hand_mod = 0 },
    { ante = 3, quota_mod = 10, hand_mod = 0 },
    { ante = 4, quota_mod = 15, hand_mod = -1, applies_to = { M.BLIND_TYPE.BOSS } },
    { ante = 5, quota_mod = 20, hand_mod = -1, applies_to = { M.BLIND_TYPE.BIG, M.BLIND_TYPE.BOSS } },
    { ante = 6, quota_mod = 25, hand_mod = -1, applies_to = "all", min_hands = 2 },
  },
  board_overrides = {
    backyard = { quota_mult = 0.8 },
    jungle = { quota_mult = 1.0 },
    mountains = { quota_mult = 1.0 },
    beach = { quota_mult = 1.0 },
    cloudbenders = { quota_mult = 1.1 },
    cavedwellers = { quota_mult = 1.1 },
    aquatic = { quota_mult = 1.1 },
    space = { quota_mult = 1.2 },
    mars = { quota_mult = 1.2 },
    dinosaurs = { quota_mult = 1.3 },
    japan = { quota_mult = 1.4 },
  },
}

M.HEART_CONFIG = {
  max_hearts = 5,
  starting_hearts = {
    novice = 4,
    regular = 3,
    veteran = 2,
    gambler = 3,
    survivor = 2,
    perfectionist = 1,
    patient = 3,
    efficient = 2,
  },
  heart_loss_triggers = {
    miss_quota = true,
    exceed_hands = true,
    fail_required_phase = true,
  },
  heart_gain_triggers = {
    exceed_50_percent = true,
    board_complete = true,
    items = true,
  },
}

M.CHARACTER_CONFIG = {
  novice = {
    name = "The Novice",
    starting_hearts = 4,
    special_ability = nil,
    unlock_condition = nil,
    unlocked = true,
  },
  regular = {
    name = "The Regular",
    starting_hearts = 3,
    special_ability = "start_money_8",
    unlock_condition = "complete_backyard",
    unlocked = false,
  },
  veteran = {
    name = "The Veteran",
    starting_hearts = 2,
    special_ability = "start_with_auntie",
    unlock_condition = "complete_3_boards",
    unlocked = false,
  },
  gambler = {
    name = "The Gambler",
    starting_hearts = 3,
    special_ability = "bet_heart",
    unlock_condition = "win_with_zero_money",
    unlocked = false,
  },
  survivor = {
    name = "The Survivor",
    starting_hearts = 2,
    special_ability = "first_loss_blocked",
    unlock_condition = "lose_5_hearts_and_win",
    unlocked = false,
  },
  perfectionist = {
    name = "The Perfectionist",
    starting_hearts = 1,
    special_ability = "exceed_restores_heart",
    unlock_condition = "exceed_50_percent_10_times",
    unlocked = false,
  },
  patient = {
    name = "The Patient One",
    starting_hearts = 3,
    special_ability = "plus_one_hand_limit",
    unlock_condition = "never_exceed_hand_limit_full_board",
    unlocked = false,
  },
  efficient = {
    name = "The Efficient",
    starting_hearts = 2,
    special_ability = "minus_hand_minus_quota",
    unlock_condition = "complete_board_2_hands_per_street",
    unlocked = false,
  },
}

return M
