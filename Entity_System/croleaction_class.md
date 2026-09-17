# CRoleAction Class — Entity Action/Command Processor
## Source: F:\CQ2ClientRelease-42.0.1\3DRole\Role.cpp
## Used by: CRole (via vtable dispatch)

---

## Overview

CRoleAction handles the entity command/action state machine. Each entity (CRole) has an action
processor that executes movement, combat, skill, and interaction commands. The processor operates
as a state machine with states: 0 (init), 2 (in-progress-A), 3 (in-progress-B), 4 (transition),
5 (sub-state), 6 (complete).

The central dispatcher `ProcessCommand` routes the current command type (field offset 122) to
the appropriate handler function.

## Key Fields (DWORD offsets from `this`)

| Offset | Field | Description |
|--------|-------|-------------|
| 95 | direction | Current facing direction (0-7, 8 directions) |
| 101-102 | screen_start_x/y | Screen start position |
| 103-104 | screen_dest_x/y | Screen destination position |
| 105 | action_anim | Current animation action code |
| 111+ | pathfinder | Pathfinding state object |
| 122 | command_type | Current command type enum |
| 123 | command_state | State machine state (0/2/3/4/5/6) |
| 126 | queued_action | Queued follow-up action |
| 128 | callback_param | Callback parameter |
| 129 | target_entity_id | Target entity ID |
| 130-131 | target_tile_x/y | Target tile coordinates |
| 132 | saved_direction | Saved facing direction |
| 137 | action_param | Action parameter |
| 138 | walk_distance | Walk distance parameter |
| 212-213 | current_screen_x/y | Current screen position |
| 223 | timestamp | Action start timestamp |
| 230 | prev_action_anim | Previous animation code |
| 232 | texas_flag | Texas Hold'em actor flag |

## Command Type Enum

From assert strings and dispatcher analysis:

| Value | Name | Handler |
|-------|------|---------|
| 1 | COMMAND_WALK_TO | ProcessWalkToPoint |
| 2 | (vtable) | sub_7379A2 |
| 3 | COMMAND_CHASE | ProcessWalkToTarget |
| 4 | (combat) | sub_7344B7 |
| 6 | (combat) | sub_73450B |
| 7 | (unknown) | sub_7371C0 |
| 8/26 | (combat) | sub_734317 |
| 9 | COMMAND_MINE | ProcessMine |
| 10 | (interact) | sub_735B15 |
| 12 | (sit/stand) | sub_734A77 |
| 13 | COMMAND_TEXAS_STAND | ProcessTexasStand |
| 14 | (emote) | sub_735AD0 |
| 15 | (vtable 60) | virtual |
| 16 | (vtable 64) | virtual |
| 17 | (walk) | sub_7363A9 |
| 18 | STOP_AUTORUN | CHero__StopAutoRun |
| 19 | COMMAND_RIDE | ProcessRide |
| 20 | (skill) | sub_73597B |
| 21 | (skill) | sub_7358DB |
| 22 | (unknown) | sub_7365CF |
| 23 | (unknown) | sub_736AC2 |
| 24 | COMMAND_RIDEFORWARD | ProcessRideForward |
| 25 | COMMAND_MUTUAL | ProcessMutualAction |
| 27/29 | (combat) | sub_734743 |
| 30 | (skill) | sub_7348BA |
| 31 | (combat) | sub_734C92 |
| 32 | COMMAND_JUMP | virtual (vtable 52) |
| 33 | COMMAND_DASH | virtual (vtable 56) |
| 34 | COMMAND_TARGET_CHASE | ProcessTargetChase |
| 36 | (walk) | sub_733C5F |
| 37 | COMMAND_SCAPEGOAT | Role_CommandType37_SelectScapegoatActionSequence |
| 38 | COMMAND_TEXAS_WALK | ProcessTexasWalk |
| 39 | COMMAND_TEXAS_SIT | ProcessTexasSit |
| 40 | COMMAND_CTRL_ACTION | ProcessCtrlAction |
| 41 | COMMAND_BE_BROWBEAT | ProcessBeBrowbeat |
| 42 | (combat) | sub_73717D |
| 43 | COMMAND_BE_HIT_FLYING | ProcessBeHitFlying |
| 44 | COMMAND_DRAGON_SKILL | ProcessDragonSkill |
| 45 | COMMAND_ICE_QUEEN_SKILL | ProcessIceQueenSkill |
| 46 | COMMAND_ASPECTWORLD | ProcessAspectWorld |
| 47 | (combat) | sub_735E11 |

## Functions (22 total)

### CRoleAction__ProcessCommand (0x64F154, size=596)
**Purpose**: Central action dispatcher. Routes command_type to handler.
```
- Checks if command_state == 6 (complete), returns via vtable[108]
- If not Texas actor and cmd != 36/37, clears texas flag
- If state == 0 and queued_action exists, fires queued_action via vtable[136]
- Switch on command_type (0-47+) to appropriate handler
- On completion, fires follow-up via vtable[140] if queued_action exists
```

### CRoleAction__NewAction (0x655194, size=3836)
**Purpose**: Initiates a new action on the entity.
```
- Validates and configures action parameters
- Sets command_type, target, direction, animation
- Transitions state machine to initial state
```

### CRoleAction__ZeroInit_64D033 (0x64D033, size=47)
**Purpose**: Zero-initializes action state fields.

### CRoleAction__ProcessBumpBack (0x73399A, size=390)
**Purpose**: Handles being bumped/knocked back.
```
Assert: _COMMAND_BE_BUMP_BACK == m_Info.cmdProc.iType
```

### CRoleAction__ProcessQuickMove (0x733B20, size=319)
**Purpose**: Handles quick/instant movement.
```
Assert: _COMMAND_BE_QUICKHAND == m_Info.cmdProc.iType
```

### CRoleAction__ProcessMine (0x7335F7, size=103)
**Purpose**: Handles mining action (command type 9).
```
Assert: _COMMAND_MINE == m_Info.cmdProc.iType
- Sets animation to 290 (mining animation)
- Copies current screen pos to start/dest
- Transitions to state 6 (complete)
```

### CRoleAction__ProcessTargetChase (0x73365E, size=828)
**Purpose**: Chase and interact with a target entity (command type 34).
```
State machine:
- State 0/init: Find target entity, compute path
- State 2/3: Walk toward target, alternating walk animations (120/121)
- If adjacent to target: set direction, play action 470, transition to state 6
- If target not found: clear path, set state 6
Uses EntityManager__FindEntityById to locate target
```

### CRoleAction__ProcessTexasWalk (0x733ECF, size=455)
**Purpose**: Texas Hold'em table walk movement (command type 38).
```
Assert: m_bIsTexasActor, cmd == 38
- Requires Texas actor flag (offset 936)
- State 0: Clear path, start walking (anim 100 or 223)
- State 2/3: Pathfind to table position, alternate walk anims
- On arrival: set position, direction, transition to state 6
```

### CRoleAction__ProcessTexasSit (0x734096, size=463)
**Purpose**: Texas Hold'em sit at table (command type 39).
```
Assert: m_bIsTexasActor, cmd == 39
- Requires Texas actor flag
- State 0: Clear path, begin sit sequence
- State 2/3: Walk to chair position
- State 4: Transition to stand (cmd 13), then sit animation 221
```

### CRoleAction__ProcessTexasStand (0x734265, size=178)
**Purpose**: Texas Hold'em stand from table (command type 13).
```
Assert: m_bIsTexasActor, cmd == 13
- Sets animation to 222 (stand up from chair)
- Copies target position to screen positions
- If state != 6: transitions to state 2
```

### CRoleAction__ProcessWalkToTarget (0x7350B3, size=1585)
**Purpose**: Complex pathfinding walk toward a target entity (command type 3).
```
Assert: hero entity ID == map singleton hero
- Finds target entity via EntityManager
- Computes path with status flag 50 (mounted?) detection
- When mounted and distance > 1: uses diagonal smoothing with direction interpolation
- Handles obstacle avoidance and direction correction:
  - Difference of 1: applies +8 offset
  - Difference of 2/6: averages directions
  - Difference of 7: applies +16 offset
- Walk animations: 110/111 (normal), 120/121 (fast), 122/123 (mounted)
- On path failure: transitions to state 6
```

### CRoleAction__ProcessWalkToPoint (0x7356E4, size=503)
**Purpose**: Walk to a fixed point on the map (command type 1).
```
Assert: cmd == 1
- State 0: Compute path from current to target position
- State 2/3: Follow path, alternate walk animations (120/121)
- When at destination: play action 280, set state 6
- On path failure: clear path, set state 6
```

### CRoleAction__ProcessBeBrowbeat (0x735BFD, size=205)
**Purpose**: Handle being browbeaten/intimidated (command type 41).
```
Assert: _COMMAND_BE_BROWBEAT
State machine:
- State 0: Play animation 703 (intimidation start), set state 3
- State 2: Play animation 100 (idle), set state 6, call sub_6E5E75(0)
- State 3: Play animation 704 (intimidation loop), set state 2
```

### CRoleAction__ProcessCtrlAction (0x735CCA, size=327)
**Purpose**: Controlled/teleport action (command type 40).
```
Assert: _COMMAND_CTRL_ACTION
State machine:
- State 0: Set animation from param, set direction, calc screen pos
- State 2: Set tile position, update map info, add visual effect (type 3, 5000ms)
  Plays "KoTeleport" sound effect, sets animation 300, completes
```

### CRoleAction__ProcessRide (0x736B14, size=1423)
**Purpose**: Mount/ride movement with autorun (command type 19).
```
Assert: _COMMAND_RIDE
- If entity is hero: checks status flag 50 (mounted), falls back to walk if not mounted
- Complex pathfinding with diagonal smoothing (same algorithm as ProcessWalkToTarget)
- On path exhaustion: checks if hero, triggers autorun end notification
  Posts message 0x478 to main window
  Shows "AutorunEnd" chat message (ID 11128)
- Walk animations: 110/111 (normal), 120/121 (fast), 122/123 (mounted)
```

### CRoleAction__ProcessRideForward (0x7370A3, size=218)
**Purpose**: Ride forward / forced mount movement (command type 24).
```
Assert: _COMMAND_RIDEFORWARD
- Sets direction from saved_direction
- Calculates destination using direction tables
- Sets animation 122/123 (mounted walk)
- Immediately completes (state 6)
```

### Role_CommandType37_SelectScapegoatActionSequence (0x733DAC, size=235)
**Purpose**: Drives the scapegoat action sequence (command type 37 / dispatcher case `0x25`).
```
State machine:
- State 0/init:
  - clears scapegoat offset-Y gate flag (`role+0x394 = 0`)
  - clears MotionPath nodes
  - mirrors current projected screen point (`0x350/0x354`) into both
    projected-point caches (`0x194/0x198`, `0x19C/0x1A0`)
  - sets skip-render flag (`role+0x3A0 = 1`)
  - sets action `0x38D`
  - advances to state 2
- State 2:
  - clears skip-render flag and keeps scapegoat offset-Y gate flag clear
  - sets action `0x38E`
  - projects staged tile `0x208/0x20C` to screen and mirrors the result into
    `0x194/0x198`, `0x19C/0x1A0`, and `0x350/0x354`
  - copies staged direction `0x210` to `0x17C`
  - advances to state 3
- State 3:
  - if action is still running, keeps skip-render clear and returns 0
  - on completion:
    - sets skip-render flag (`role+0x3A0 = 1`)
    - sets scapegoat offset-Y gate flag (`role+0x394 = 1`)
    - returns 1
- fallback terminal branch:
  - clears skip-render flag
  - writes action `0x191`
  - sets state 6
```

### CRoleAction__ProcessMutualAction (0x737246, size=400)
**Purpose**: Mutual/paired interaction between entities (command type 25).
```
Assert: _COMMAND_MUTUAL
- Handles complex animation sequences for paired interactions
- Clears RoleView slots 7 and 6
- State 0: Sets animation from action_param, handles special cases:
  - 296, 504, 515, 518, 625, 628, 631: set state 6 (one-shot)
  - Others: set state 2 (looping)
- State 2: Animation chaining:
  - 633→634, 636→637, 639→640 (sequence progressions)
  - 18-21: paired emote sequence
  - 503, 514, 522→521: paired interaction chains
  - After chain: set state 5 (sub-state), then state 6
```

### CRoleAction__ProcessIceQueenSkill (0x7373D6, size=384)
**Purpose**: Ice Queen skill visual sequence (command type 45).
```
Assert: _COMMAND_ICE_QUEEN_SKILL
State machine:
- State 0: Sets initial animation from param
  - If 401: random between 484 (standard) or 657
  - If 500: immediate complete
  - Others: state 2
- State 2: Multi-frame animation chains:
  - 485→486→487, 488→489→490, 491→492→493, 498→499
  - 499: saves direction, completes
```

### CRoleAction__ProcessDragonSkill (0x737596, size=431)
**Purpose**: Dragon skill visual sequence (command type 44).
```
Assert: _COMMAND_DRAGON_SKILL
- Similar structure to IceQueenSkill
- State 0: Sets animation from param
  - If 401: random between 403 or 402
  - If 495: immediate complete
  - Others: state 2
- State 2/3: Multi-frame animation chains:
  - 485→486, 489, 492, 499→500, 501→502→503
- State 5: Checks 495, transitions
```

### CRoleAction__ProcessBeHitFlying (0x737745, size=366)
**Purpose**: Being hit and knocked flying (command type 43).
```
Assert: _COMMAND_BE_HIT_FLYING
- State 0: Sets animation 482, direction to opposite (+4 mod 8)
  - If not hero: calculates landing position using direction table * walk_distance
  - Computes destination screen position
  - Sets state 2
- State 2: Calls callback (vtable[124] with callback_param)
  - Sets idle animation 100, completes
```

### CRoleAction__ProcessAspectWorld (0x7378B3, size=239)
**Purpose**: Aspect/dimension world transition (command type 46).
```
Assert: _COMMAND_ASPECTWORLD
- State 0: Clears pathfinder, initializes position interpolation
  - Sets animation 919 (portal/warp visual)
  - Calculates destination screen position
  - Sets state 2
- State 2: Sets tile position from target, animation 100 (idle), completes
```

## Helper Address Index

| Function | Address |
|---|---|
| CRoleAction__ProcessCommand | 0x64F154 |
| CRoleAction__NewAction | 0x655194 |
| CRoleAction__ZeroInit_64D033 | 0x64D033 |
| CRoleAction__ProcessBumpBack | 0x73399A |
| CRoleAction__ProcessQuickMove | 0x733B20 |
| CRoleAction__ProcessMine | 0x7335F7 |
| CRoleAction__ProcessTargetChase | 0x73365E |
| Role_CommandType37_SelectScapegoatActionSequence | 0x733DAC |
| CRoleAction__ProcessTexasWalk | 0x733ECF |
| CRoleAction__ProcessTexasSit | 0x734096 |
| CRoleAction__ProcessTexasStand | 0x734265 |
| CRoleAction__ProcessWalkToTarget | 0x7350B3 |
| CRoleAction__ProcessWalkToPoint | 0x7356E4 |
| CRoleAction__ProcessBeBrowbeat | 0x735BFD |
| CRoleAction__ProcessCtrlAction | 0x735CCA |
| CRoleAction__ProcessRide | 0x736B14 |
| CRoleAction__ProcessRideForward | 0x7370A3 |
| CRoleAction__ProcessMutualAction | 0x737246 |
| CRoleAction__ProcessIceQueenSkill | 0x7373D6 |
| CRoleAction__ProcessDragonSkill | 0x737596 |
| CRoleAction__ProcessBeHitFlying | 0x737745 |
| CRoleAction__ProcessAspectWorld | 0x7378B3 |
