import Foundation
import GRDB
import Vapor
import Argon2Swift

enum FakeDataSeeder {
    private struct SeededPlayableGame {
        let gameMetaId: UUID
        let gameHashId: UUID
        let compatibilityId: UUID
        let contentHash: String?
        let savePrefix: String
        let saveNotes: String
    }

    private struct CompatibilitySeed {
        let key: String
        let notes: String
    }

    private struct GameSeed {
        let key: String
        let familyKey: String
        let compatibilityKey: String
        let name: String
        let version: String?
        let executable: String
        let hashSeeds: [String]
        let baseGameKey: String?
        let breaksPrevious: Bool
        let breaksBase: Bool
        let contentHash: String?
        let savePrefix: String?
        let saveNotes: String?
        let createdOffset: TimeInterval
    }

    private struct ScenarioSeed {
        let compatibilities: [CompatibilitySeed]
        let games: [GameSeed]
    }

    private static func rotl(_ value: UInt64, _ amount: UInt64) -> UInt64 {
        (value << amount) | (value >> (64 - amount))
    }

    private static func readUInt64LE(_ bytes: [UInt8], _ index: Int) -> UInt64 {
        var value: UInt64 = 0
        for offset in 0..<8 {
            value |= UInt64(bytes[index + offset]) << UInt64(offset * 8)
        }
        return value
    }

    private static func readUInt32LE(_ bytes: [UInt8], _ index: Int) -> UInt32 {
        var value: UInt32 = 0
        for offset in 0..<4 {
            value |= UInt32(bytes[index + offset]) << UInt32(offset * 8)
        }
        return value
    }

    private static func xxHash64Round(_ accumulator: UInt64, _ input: UInt64) -> UInt64 {
        let prime1: UInt64 = 11400714785074694791
        let prime2: UInt64 = 14029467366897019727
        var acc = accumulator &+ (input &* prime2)
        acc = rotl(acc, 31)
        acc = acc &* prime1
        return acc
    }

    private static func xxHash64MergeRound(_ accumulator: UInt64, _ value: UInt64) -> UInt64 {
        let prime1: UInt64 = 11400714785074694791
        let prime4: UInt64 = 9650029242287828579
        var acc = accumulator ^ xxHash64Round(0, value)
        acc = (acc &* prime1) &+ prime4
        return acc
    }

    private static func xxHash64Hex(_ input: String) -> String {
        let prime1: UInt64 = 11400714785074694791
        let prime2: UInt64 = 14029467366897019727
        let prime3: UInt64 = 1609587929392839161
        let prime4: UInt64 = 9650029242287828579
        let prime5: UInt64 = 2870177450012600261

        let bytes = Array(input.utf8)
        let count = bytes.count
        var index = 0
        let hash: UInt64

        if count >= 32 {
            var v1 = prime1 &+ prime2
            var v2 = prime2
            var v3: UInt64 = 0
            var v4 = 0 &- prime1

            while index <= count - 32 {
                v1 = xxHash64Round(v1, readUInt64LE(bytes, index))
                index += 8
                v2 = xxHash64Round(v2, readUInt64LE(bytes, index))
                index += 8
                v3 = xxHash64Round(v3, readUInt64LE(bytes, index))
                index += 8
                v4 = xxHash64Round(v4, readUInt64LE(bytes, index))
                index += 8
            }

            var result = rotl(v1, 1) &+ rotl(v2, 7) &+ rotl(v3, 12) &+ rotl(v4, 18)
            result = xxHash64MergeRound(result, v1)
            result = xxHash64MergeRound(result, v2)
            result = xxHash64MergeRound(result, v3)
            result = xxHash64MergeRound(result, v4)
            hash = result &+ UInt64(count)
        } else {
            hash = prime5 &+ UInt64(count)
        }

        var result = hash

        while index <= count - 8 {
            let k1 = xxHash64Round(0, readUInt64LE(bytes, index))
            result ^= k1
            result = rotl(result, 27)
            result = (result &* prime1) &+ prime4
            index += 8
        }

        if index <= count - 4 {
            result ^= UInt64(readUInt32LE(bytes, index)) &* prime1
            result = rotl(result, 23)
            result = (result &* prime2) &+ prime3
            index += 4
        }

        while index < count {
            result ^= UInt64(bytes[index]) &* prime5
            result = rotl(result, 11) &* prime1
            index += 1
        }

        result ^= result >> 33
        result = result &* prime2
        result ^= result >> 29
        result = result &* prime3
        result ^= result >> 32

        return String(format: "%016llx", result)
    }

    private static func scenarioSeeds() -> [ScenarioSeed] {
        let compatibilityScenarios: [ScenarioSeed] = [
            ScenarioSeed(
                compatibilities: [
                    CompatibilitySeed(
                        key: "witcher3-cross-build",
                        notes: "Same game, same save format, different launcher and platform builds."
                    )
                ],
                games: [
                    GameSeed(
                        key: "witcher3-404",
                        familyKey: "witcher3",
                        compatibilityKey: "witcher3-cross-build",
                        name: "The Witcher 3: Wild Hunt",
                        version: "4.04",
                        executable: "witcher3.exe",
                        hashSeeds: [
                            "The Witcher 3 Steam Windows 4.04",
                            "The Witcher 3 GOG Windows 4.04",
                            "The Witcher 3 Steam Proton 4.04"
                        ],
                        baseGameKey: nil,
                        breaksPrevious: false,
                        breaksBase: false,
                        contentHash: nil,
                        savePrefix: "Witcher 3 Cross-Build",
                        saveNotes: "Cross-build compatibility scenario: Steam, GOG, and Proton builds should all see the same saves.",
                        createdOffset: 10
                    )
                ]
            ),
            ScenarioSeed(
                compatibilities: [
                    CompatibilitySeed(
                        key: "stardew-1x",
                        notes: "Compatible version progression where newer versions should still read older saves."
                    )
                ],
                games: [
                    GameSeed(
                        key: "stardew-156",
                        familyKey: "stardew",
                        compatibilityKey: "stardew-1x",
                        name: "Stardew Valley",
                        version: "1.5.6",
                        executable: "stardew valley.exe",
                        hashSeeds: ["Stardew Valley 1.5.6 Windows"],
                        baseGameKey: nil,
                        breaksPrevious: false,
                        breaksBase: false,
                        contentHash: nil,
                        savePrefix: "Stardew Legacy",
                        saveNotes: "Compatible version scenario: older save created before the 1.6 line.",
                        createdOffset: 20
                    ),
                    GameSeed(
                        key: "stardew-168",
                        familyKey: "stardew",
                        compatibilityKey: "stardew-1x",
                        name: "Stardew Valley",
                        version: "1.6.8",
                        executable: "stardew valley.exe",
                        hashSeeds: ["Stardew Valley 1.6.8 Windows"],
                        baseGameKey: "stardew-156",
                        breaksPrevious: false,
                        breaksBase: false,
                        contentHash: nil,
                        savePrefix: "Stardew Modern",
                        saveNotes: "Compatible version scenario: new client should still surface legacy saves.",
                        createdOffset: 21
                    )
                ]
            ),
            ScenarioSeed(
                compatibilities: [
                    CompatibilitySeed(
                        key: "bg3-early-access",
                        notes: "Seeded incompatible era representing a major save format break."
                    ),
                    CompatibilitySeed(
                        key: "bg3-release",
                        notes: "Seeded post-release compatibility era that should not be mixed with early access."
                    )
                ],
                games: [
                    GameSeed(
                        key: "bg3-ea",
                        familyKey: "bg3",
                        compatibilityKey: "bg3-early-access",
                        name: "Baldur's Gate 3",
                        version: "0.9",
                        executable: "bg3_dx11.exe",
                        hashSeeds: ["Baldurs Gate 3 Early Access 0.9"],
                        baseGameKey: nil,
                        breaksPrevious: false,
                        breaksBase: false,
                        contentHash: nil,
                        savePrefix: "BG3 Early Access",
                        saveNotes: "Breaking-version scenario: early access save that should not be treated as release-compatible.",
                        createdOffset: 30
                    ),
                    GameSeed(
                        key: "bg3-100",
                        familyKey: "bg3",
                        compatibilityKey: "bg3-release",
                        name: "Baldur's Gate 3",
                        version: "1.0",
                        executable: "bg3_dx11.exe",
                        hashSeeds: ["Baldurs Gate 3 Release 1.0"],
                        baseGameKey: "bg3-ea",
                        breaksPrevious: true,
                        breaksBase: false,
                        contentHash: nil,
                        savePrefix: "BG3 Release",
                        saveNotes: "Breaking-version scenario: release-era save using a different compatibility bucket.",
                        createdOffset: 31
                    )
                ]
            ),
            ScenarioSeed(
                compatibilities: [
                    CompatibilitySeed(
                        key: "skyrimse-vanilla",
                        notes: "Vanilla Skyrim Special Edition compatibility bucket."
                    ),
                    CompatibilitySeed(
                        key: "enderal-se",
                        notes: "Total conversion compatibility bucket. Base game relationship exists, but saves should not be mixed automatically."
                    )
                ],
                games: [
                    GameSeed(
                        key: "skyrimse-16640",
                        familyKey: "skyrimse",
                        compatibilityKey: "skyrimse-vanilla",
                        name: "The Elder Scrolls V: Skyrim Special Edition",
                        version: "1.6.640",
                        executable: "SkyrimSE.exe",
                        hashSeeds: ["Skyrim Special Edition 1.6.640"],
                        baseGameKey: nil,
                        breaksPrevious: false,
                        breaksBase: false,
                        contentHash: nil,
                        savePrefix: "Skyrim SE Vanilla",
                        saveNotes: "Base game save used for the total-conversion comparison scenario.",
                        createdOffset: 40
                    ),
                    GameSeed(
                        key: "enderalse-2012",
                        familyKey: "enderalse",
                        compatibilityKey: "enderal-se",
                        name: "Enderal: Forgotten Stories (Special Edition)",
                        version: "2.0.12",
                        executable: "EnderalSE.exe",
                        hashSeeds: ["Enderal Special Edition 2.0.12"],
                        baseGameKey: "skyrimse-16640",
                        breaksPrevious: false,
                        breaksBase: true,
                        contentHash: "enderal-total-conversion",
                        savePrefix: "Enderal SE",
                        saveNotes: "Total conversion scenario: derived from Skyrim but save compatibility is intentionally separate.",
                        createdOffset: 41
                    )
                ]
            ),
            ScenarioSeed(
                compatibilities: [
                    CompatibilitySeed(
                        key: "skyrimse-overlap",
                        notes: "Overlapping install scenario where executable identity can match but content differs."
                    ),
                    CompatibilitySeed(
                        key: "skyrimse-heavy-mods",
                        notes: "Heavily modded Skyrim scenario with shared executable hash but different content requirements."
                    )
                ],
                games: [
                    GameSeed(
                        key: "skyrimse-vanillaplus",
                        familyKey: "skyrimse",
                        compatibilityKey: "skyrimse-overlap",
                        name: "The Elder Scrolls V: Skyrim Special Edition - Vanilla+",
                        version: "1.6.640",
                        executable: "SkyrimSE.exe",
                        hashSeeds: ["Shared Skyrim SE executable 1.6.640"],
                        baseGameKey: "skyrimse-16640",
                        breaksPrevious: false,
                        breaksBase: false,
                        contentHash: "modlist-vanilla-plus-2026",
                        savePrefix: "Skyrim Vanilla+",
                        saveNotes: "Overlapping install scenario: same EXE fingerprint, different plugin set.",
                        createdOffset: 42
                    ),
                    GameSeed(
                        key: "skyrimse-lotd",
                        familyKey: "skyrimse",
                        compatibilityKey: "skyrimse-heavy-mods",
                        name: "The Elder Scrolls V: Skyrim Special Edition - Legacy of the Dragonborn",
                        version: "1.6.640",
                        executable: "SkyrimSE.exe",
                        hashSeeds: ["Shared Skyrim SE executable 1.6.640"],
                        baseGameKey: "skyrimse-16640",
                        breaksPrevious: false,
                        breaksBase: true,
                        contentHash: "modlist-legacy-of-the-dragonborn-v6",
                        savePrefix: "Skyrim LOTD",
                        saveNotes: "Shared-executable edge case: hash matches vanilla but content_hash distinguishes the modded environment.",
                        createdOffset: 43
                    )
                ]
            ),
            ScenarioSeed(
                compatibilities: [
                    CompatibilitySeed(
                        key: "hades-cross-platform",
                        notes: "Cross-platform scenario with mutually compatible saves."
                    )
                ],
                games: [
                    GameSeed(
                        key: "hades-win",
                        familyKey: "hades",
                        compatibilityKey: "hades-cross-platform",
                        name: "Hades (Windows)",
                        version: "1.38290",
                        executable: "Hades.exe",
                        hashSeeds: ["Hades Windows 1.38290"],
                        baseGameKey: nil,
                        breaksPrevious: false,
                        breaksBase: false,
                        contentHash: nil,
                        savePrefix: "Hades Windows",
                        saveNotes: "Cross-platform scenario: Windows save.",
                        createdOffset: 50
                    ),
                    GameSeed(
                        key: "hades-macos",
                        familyKey: "hades",
                        compatibilityKey: "hades-cross-platform",
                        name: "Hades (macOS)",
                        version: "1.38290",
                        executable: "Hades.app",
                        hashSeeds: ["Hades macOS 1.38290"],
                        baseGameKey: "hades-win",
                        breaksPrevious: false,
                        breaksBase: false,
                        contentHash: nil,
                        savePrefix: "Hades macOS",
                        saveNotes: "Cross-platform scenario: macOS save in the same compatibility bucket.",
                        createdOffset: 51
                    )
                ]
            ),
            ScenarioSeed(
                compatibilities: [
                    CompatibilitySeed(
                        key: "mass-effect-import",
                        notes: "Import/remaster scenario. The current schema can only represent this through notes and compatibility bucketing."
                    )
                ],
                games: [
                    GameSeed(
                        key: "mass-effect-2007",
                        familyKey: "mass-effect",
                        compatibilityKey: "mass-effect-import",
                        name: "Mass Effect",
                        version: "1.02",
                        executable: "MassEffect.exe",
                        hashSeeds: ["Mass Effect 2007 1.02"],
                        baseGameKey: nil,
                        breaksPrevious: false,
                        breaksBase: false,
                        contentHash: nil,
                        savePrefix: "Mass Effect Original",
                        saveNotes: "Import scenario: original trilogy save intended for remaster testing.",
                        createdOffset: 60
                    ),
                    GameSeed(
                        key: "mass-effect-le",
                        familyKey: "mass-effect-le",
                        compatibilityKey: "mass-effect-import",
                        name: "Mass Effect Legendary Edition",
                        version: "2.0.0",
                        executable: "MassEffectLauncher.exe",
                        hashSeeds: ["Mass Effect Legendary Edition 2.0.0"],
                        baseGameKey: "mass-effect-2007",
                        breaksPrevious: false,
                        breaksBase: true,
                        contentHash: nil,
                        savePrefix: "Mass Effect Legendary",
                        saveNotes: "Import scenario: remaster-side data. Current schema notes the relationship but does not model directional compatibility rules yet.",
                        createdOffset: 61
                    )
                ]
            ),
            ScenarioSeed(
                compatibilities: [
                    CompatibilitySeed(
                        key: "monster-hunter-iceborne",
                        notes: "DLC/content dependency scenario where content requirements matter in addition to compatibility."
                    )
                ],
                games: [
                    GameSeed(
                        key: "mhw-iceborne",
                        familyKey: "monster-hunter-world",
                        compatibilityKey: "monster-hunter-iceborne",
                        name: "Monster Hunter: World - Iceborne",
                        version: "15.22.00",
                        executable: "MonsterHunterWorld.exe",
                        hashSeeds: ["Monster Hunter World Iceborne 15.22.00"],
                        baseGameKey: nil,
                        breaksPrevious: false,
                        breaksBase: false,
                        contentHash: "requires-iceborne-dlc",
                        savePrefix: "Iceborne Hunter",
                        saveNotes: "DLC edge case: save depends on Iceborne content even if the base executable family matches.",
                        createdOffset: 70
                    )
                ]
            )
        ]

        let fillerTitles: [(String, String, String)] = [
            ("Celeste", "Celeste.exe", "1.4.0.0"),
            ("Hollow Knight", "HollowKnight.exe", "1.5.78.11833"),
            ("Dead Cells", "deadcells.exe", "35.0"),
            ("Slay the Spire", "SlayTheSpire.exe", "2.3"),
            ("Factorio", "factorio.exe", "2.0.28"),
            ("RimWorld", "RimWorldWin64.exe", "1.5.4104"),
            ("Valheim", "valheim.exe", "0.218.15"),
            ("Disco Elysium", "Disco Elysium.exe", "b2024"),
            ("Portal 2", "portal2.exe", "1.0.0.1"),
            ("Terraria", "Terraria.exe", "1.4.4.9"),
            ("FTL: Faster Than Light", "FTLGame.exe", "1.6.14"),
            ("Subnautica", "Subnautica.exe", "72286"),
            ("Satisfactory", "FactoryGameSteam.exe", "1.0.0"),
            ("Frostpunk", "Frostpunk.exe", "1.6.2"),
            ("Crusader Kings III", "ck3.exe", "1.12.5"),
            ("XCOM 2", "XCom2.exe", "1.0.0"),
            ("Divinity: Original Sin 2", "EoCApp.exe", "3.6.117.3735"),
            ("Elden Ring", "eldenring.exe", "1.13"),
            ("No Man's Sky", "NMS.exe", "5.20"),
            ("Dave the Diver", "DAVE THE DIVER.exe", "1.0.3.1379"),
            ("Against the Storm", "AgainstTheStorm.exe", "1.3.2"),
            ("Hades II", "Hades2.exe", "0.92"),
            ("Vampire Survivors", "VampireSurvivors.exe", "1.10.106"),
            ("Into the Breach", "IntoTheBreach.exe", "1.2.88"),
            ("Balatro", "Balatro.exe", "1.0.1m"),
            ("Darkest Dungeon", "Darkest.exe", "25687"),
            ("Project Zomboid", "ProjectZomboid64.exe", "42.1"),
            ("Against the Storm (GOG)", "AgainstTheStorm.exe", "1.3.2")
        ]

        let fillerScenario = ScenarioSeed(
            compatibilities: fillerTitles.map {
                CompatibilitySeed(
                    key: "compat-\($0.0.lowercased().replacingOccurrences(of: " ", with: "-"))",
                    notes: "Single-title compatibility bucket for paging and list validation."
                )
            },
            games: fillerTitles.enumerated().map { index, filler in
                let familyKey = "family-\(filler.0.lowercased().replacingOccurrences(of: " ", with: "-"))"
                let compatKey = "compat-\(filler.0.lowercased().replacingOccurrences(of: " ", with: "-"))"
                return GameSeed(
                    key: "game-\(index)-\(familyKey)",
                    familyKey: familyKey,
                    compatibilityKey: compatKey,
                    name: filler.0,
                    version: filler.2,
                    executable: filler.1,
                    hashSeeds: ["\(filler.0) \(filler.2)"],
                    baseGameKey: nil,
                    breaksPrevious: false,
                    breaksBase: false,
                    contentHash: nil,
                    savePrefix: filler.0,
                    saveNotes: "Additional seeded library title used to exercise paging in the games UI.",
                    createdOffset: 100 + Double(index)
                )
            }
        )

        return compatibilityScenarios + [fillerScenario]
    }

    private static func makeSeedUser(index: Int, now: Date) throws -> User {
        let salt = Salt.newSalt()
        let username:String
        let email:String
        if (index == 0) {
            username = "izackp"
            email = "izackp@gmail.com"
        } else {
            username = "seed_user_\(index)"
            email = "seed_user_\(index)@example.com"
        }
        let passwordHash = try Argon2Swift.hashPasswordString(password: "Password12", salt: salt).encodedString()
        return User(
            id: SmallUid(),
            username: username,
            email: email,
            passwordHash: passwordHash,
            isAdmin: index == 0,
            createdAt: now,
            updatedAt: now
        )
    }

    static func seedGamesAndSaves(
        _ db: GRDB.Database,
        usersCount: Int = 3,
        profilesPerUser: Int = 2,
        savesPerProfile: Int = 2
    ) throws {
        let now = Date()
        var familyIds = [String: UUID]()
        var compatibilityIds = [String: UUID]()
        var gameIds = [String: UUID]()
        var playableGames = [SeededPlayableGame]()

        for scenario in scenarioSeeds() {
            for compatibilitySeed in scenario.compatibilities {
                if compatibilityIds[compatibilitySeed.key] == nil {
                    let compatibilityId = UUID()
                    compatibilityIds[compatibilitySeed.key] = compatibilityId
                    var compatibility = Compatibility(
                        id: compatibilityId,
                        notes: compatibilitySeed.notes,
                        updatedAt: now
                    )
                    try compatibility.insert(db)
                }
            }

            for gameSeed in scenario.games {
                let familyId = familyIds[gameSeed.familyKey] ?? {
                    let id = UUID()
                    familyIds[gameSeed.familyKey] = id
                    return id
                }()
                let compatibilityId = compatibilityIds[gameSeed.compatibilityKey]!
                let baseGameId = gameSeed.baseGameKey.flatMap { gameIds[$0] }
                let createdAt = now.addingTimeInterval(gameSeed.createdOffset)
                let hashes = gameSeed.hashSeeds.map { xxHash64Hex($0) }
                let primaryHash = hashes.first

                let gameId = UUID()
                var game = GameMeta(
                    id: gameId,
                    familyId: familyId,
                    baseGameId: baseGameId,
                    hashedFileName: gameSeed.executable,
                    xxhash64: primaryHash,
                    name: gameSeed.name,
                    version: gameSeed.version,
                    breaksSaveFormatFromPreviousVersion: gameSeed.breaksPrevious,
                    breaksSaveFormatFromBaseGame: gameSeed.breaksBase,
                    createdAt: createdAt,
                    updatedAt: createdAt
                )
                try game.insert(db)
                gameIds[gameSeed.key] = gameId

                var firstHashId: UUID?
                for (hashIndex, hash) in hashes.enumerated() {
                    let hashId = UUID()
                    var gameHash = GameHash(
                        id: hashId,
                        gameMetaId: gameId,
                        hashedFileName: gameSeed.executable,
                        xxhash64: hash,
                        createdAt: createdAt.addingTimeInterval(TimeInterval(hashIndex)),
                        updatedAt: createdAt.addingTimeInterval(TimeInterval(hashIndex))
                    )
                    try gameHash.insert(db)
                    if firstHashId == nil {
                        firstHashId = hashId
                    }
                }

                if let firstHashId, let savePrefix = gameSeed.savePrefix, let saveNotes = gameSeed.saveNotes {
                    playableGames.append(
                        SeededPlayableGame(
                            gameMetaId: gameId,
                            gameHashId: firstHashId,
                            compatibilityId: compatibilityId,
                            contentHash: gameSeed.contentHash,
                            savePrefix: savePrefix,
                            saveNotes: saveNotes
                        )
                    )
                }
            }
        }

        for userIndex in 0..<usersCount {
            var user = try makeSeedUser(index: userIndex, now: now)
            try user.insert(db)

            for profileIndex in 0..<profilesPerUser {
                var profile = UserProfile(
                    id: SmallUid.generate(),
                    userId: user.id,
                    name: "Profile \(profileIndex + 1)",
                    createdAt: now,
                    updatedAt: now
                )
                try profile.insert(db)

                for playableGame in playableGames {
                    for saveIndex in 0..<savesPerProfile {
                        let saveTime = now.addingTimeInterval(TimeInterval((profileIndex * 100) + (saveIndex * 60)))
                        var save = Save(
                            id: UUID(),
                            gameHashId: playableGame.gameHashId,
                            gameMetaId: playableGame.gameMetaId,
                            compatibilityId: playableGame.compatibilityId,
                            sequentialId: UUID(),
                            profileId: profile.id,
                            userId: user.id,
                            url: "https://example.com/\(UUID().uuidString).zip",
                            fileSize: 1024 + saveIndex,
                            sourceDevice: "seed-device-\(userIndex)",
                            name: "\(playableGame.savePrefix) Save \(saveIndex + 1)",
                            contentHash: playableGame.contentHash,
                            notes: playableGame.saveNotes,
                            date: saveTime,
                            createdAt: saveTime,
                            updatedAt: saveTime
                        )
                        try save.insert(db)
                    }
                }
            }
        }
    }

    static func seedGamesAndSaves(
        pool: DatabasePool = DBShared.pool(),
        usersCount: Int = 3,
        profilesPerUser: Int = 2,
        savesPerProfile: Int = 2
    ) throws {
        try pool.write { db in
            try seedGamesAndSaves(
                db,
                usersCount: usersCount,
                profilesPerUser: profilesPerUser,
                savesPerProfile: savesPerProfile
            )
        }
    }

    static func seedGamesAndSavesIfEmpty(pool: DatabasePool = DBShared.pool()) throws {
        let isEmpty = try pool.read { db in
            try GameMeta.fetchCount(db) == 0
        }
        if isEmpty {
            try seedGamesAndSaves(pool: pool)
        }
    }
}
