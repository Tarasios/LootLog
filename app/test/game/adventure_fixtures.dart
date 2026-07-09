/// A fully-populated adventure [GameState] (every card kind exercised) for the
/// adventure-dashboard goldens. Built directly from the pure model constructors
/// so the goldens are deterministic and self-contained — no reducer, no async
/// image loading (the default placeholder resolver renders every sprite).
library;

import 'package:duobudget/domain/time.dart';
import 'package:duobudget/game/adapter.dart';
import 'package:duobudget/game/adventure_dashboard.dart';
import 'package:duobudget/game/game_state.dart';

const _july = Month(2026, 7);

SpriteRef _asset(String name, String label) =>
    SpriteRef.asset(name, label: label);

GameState sampleGameState() => GameState(
      currentMonth: _july,
      floorNumber: 7,
      heroName: 'Robin',
      heroSprite: _asset(Sprites.heroA, 'Robin'),
      partnerSprite: _asset(Sprites.heroB, 'Sam'),
      heroHpLostCents: 2000,
      expeditionSuppliesCents: 300000,
      monsters: [
        Monster(
          sliceId: 'food',
          name: 'Food',
          sprite: _asset(Sprites.monster, 'Food'),
          maxHpCents: 40000,
          damageCents: 25000,
          excessCents: 0,
          mine: true,
          ownerName: 'Robin',
        ),
        Monster(
          sliceId: 'fun',
          name: 'Fun',
          sprite: _asset(Sprites.monsterEnraged, 'Fun'),
          maxHpCents: 20000,
          damageCents: 22000,
          excessCents: 2000,
          mine: true,
          ownerName: 'Robin',
        ),
        Monster(
          sliceId: 'gear',
          name: 'Gear',
          sprite: _asset(Sprites.monster, 'Gear'),
          maxHpCents: 30000,
          damageCents: 12000,
          excessCents: 0,
          mine: false,
          ownerName: 'Sam',
        ),
      ],
      contracts: [
        const PartyContract(
          sliceId: 'groceries',
          name: 'Groceries',
          maxHpCents: 60000,
          damageCents: 41000,
          excessCents: 0,
        ),
      ],
      party: [
        PartyMember(
          petId: 'mochi',
          name: 'Mochi',
          sprite: _asset(Sprites.pet, 'Mochi'),
          monsters: [
            Monster(
              sliceId: 'petfood',
              name: 'Pet food',
              sprite: _asset(Sprites.monster, 'Pet food'),
              maxHpCents: 10000,
              damageCents: 4000,
              excessCents: 0,
              mine: true,
              ownerName: 'Robin',
            ),
          ],
          contracts: const [],
          reserveCaches: [
            ReserveCache(
              fundId: 'vet',
              name: 'Vet fund',
              sprite: _asset(Sprites.reserveCache, 'Vet fund'),
              balanceCents: 50000,
              petName: 'Mochi',
            ),
          ],
        ),
      ],
      questMonsters: [
        QuestMonster(
          questId: 'canoe',
          name: 'Canoe',
          sprite: _asset(Sprites.questMonster, 'Canoe'),
          targetCents: 130000,
          contributedCents: 30000,
          balanceCents: 30000,
          completed: false,
          shared: true,
          contributors: const [
            Contributor(name: 'Robin', cents: 20000),
            Contributor(name: 'Sam', cents: 10000),
          ],
        ),
        QuestMonster(
          questId: 'jacket',
          name: 'Winter jacket',
          sprite: _asset(Sprites.questMonster, 'Winter jacket'),
          targetCents: 50000,
          contributedCents: 50000,
          balanceCents: 50000,
          completed: true,
          shared: false,
          contributors: const [],
        ),
      ],
      provisioning: const [
        ProvisionLine(
          name: 'Rent',
          kind: ProvisionKind.fixedMaintenance,
          amountCents: 120000,
          shared: true,
          awaitingTally: false,
        ),
        ProvisionLine(
          name: 'Utilities',
          kind: ProvisionKind.variableMaintenance,
          amountCents: 8000,
          shared: true,
          awaitingTally: true,
        ),
        ProvisionLine(
          name: 'Vet fund',
          kind: ProvisionKind.emergencyProvision,
          amountCents: 5000,
          shared: true,
          awaitingTally: false,
        ),
      ],
      goldPouch: const GoldPouch(
        balanceCents: 8850,
        clampedFlag: false,
        projectedMintCents: 40000,
      ),
      warChest: WarChest(
        balanceCents: 214000,
        targetCents: 500000,
        pctComplete: 214000 / 500000,
        estMonthsRemaining: 6.2,
        writsForMe: const [
          Writ(
            proposalId: 'w1',
            byName: 'Sam',
            amountCents: 20000,
            purpose: 'New tent',
            destinationLabel: 'beyond the walls',
            needsMySignature: true,
          ),
        ],
        writsForOther: const [],
        ransacks: [
          RansackBanner(
            cacheName: 'Car repairs',
            excessCents: 15000,
            purpose: 'Tow truck',
            occurredAt: DateTime.utc(2026, 7, 2, 18),
          ),
        ],
      ),
      reserveCaches: [
        _reserve('Car repairs', 0),
      ],
    );

/// The same fully-populated floor, but with a party roster of every kind — the
/// device owner (owns two monsters, one enraged), another adventurer (owns one),
/// a companion with no ledger, and the pet familiar (owns the pet-linked
/// monster). Used by the pixel-dashboard goldens to exercise every party frame.
GameState sampleGameStateWithRoster() {
  final g = sampleGameState();
  return GameState(
    currentMonth: g.currentMonth,
    floorNumber: g.floorNumber,
    heroName: g.heroName,
    heroSprite: g.heroSprite,
    partnerSprite: g.partnerSprite,
    heroHpLostCents: g.heroHpLostCents,
    expeditionSuppliesCents: g.expeditionSuppliesCents,
    monsters: g.monsters,
    contracts: g.contracts,
    party: g.party,
    questMonsters: g.questMonsters,
    provisioning: g.provisioning,
    goldPouch: g.goldPouch,
    warChest: g.warChest,
    reserveCaches: g.reserveCaches,
    expeditions: g.expeditions,
    roster: [
      Adventurer(
        memberId: 'u1',
        name: 'Robin',
        role: AdventurerRole.adventurer,
        descriptionText: 'A steady hand with a ledger.',
        isMe: true,
        sprite: _asset(Sprites.heroA, 'Robin'),
      ),
      Adventurer(
        memberId: 'u2',
        name: 'Sam',
        role: AdventurerRole.adventurer,
        isMe: false,
        sprite: _asset(Sprites.heroB, 'Sam'),
      ),
      Adventurer(
        memberId: 'iris',
        name: 'Iris',
        role: AdventurerRole.companion,
        descriptionText: 'A curious young scout.',
        isMe: false,
        sprite: _asset(Sprites.heroA, 'Iris'),
      ),
      Adventurer(
        memberId: 'mochi',
        name: 'Mochi',
        role: AdventurerRole.familiar,
        descriptionText: 'A round cat of great appetite.',
        isMe: false,
        sprite: _asset(Sprites.pet, 'Mochi'),
      ),
    ],
  );
}

ReserveCache _reserve(String name, int cents) => ReserveCache(
      fundId: name,
      name: name,
      sprite: _asset(Sprites.reserveCache, name),
      balanceCents: cents,
    );

AdventureSpoilsBanner sampleSpoilsBanner() => const AdventureSpoilsBanner(
      monstersToRecap: 2,
      talliesPending: 1,
      daysRemaining: 3,
    );

/// A short adventure log in game voice, for the pixel/text dashboard goldens.
List<LogEntry> sampleAdventureLog() => [
      LogEntry(
        id: 'e1',
        line: r'GROCERIES MONSTER TAKES $42.00 DMG',
        tone: LogTone.strike,
        occurredAt: DateTime.utc(2026, 7, 3),
        isMine: true,
      ),
      LogEntry(
        id: 'e2',
        line: r'TREASURE FOUND — $50.00 for Robin',
        tone: LogTone.treasure,
        occurredAt: DateTime.utc(2026, 7, 4),
        isMine: true,
      ),
      LogEntry(
        id: 'e3',
        line: r'THE WAR CHEST WAS RANSACKED! $150.00 torn away',
        tone: LogTone.ransack,
        occurredAt: DateTime.utc(2026, 7, 2),
        isMine: false,
      ),
    ];
