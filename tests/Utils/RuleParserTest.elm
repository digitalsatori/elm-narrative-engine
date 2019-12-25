module Utils.RuleParserTest exposing (all)

import Expect
import NarrativeEngine.Core.WorldModel exposing (..)
import NarrativeEngine.Utils.Helpers exposing (parseMultiple)
import NarrativeEngine.Utils.RuleParser
    exposing
        ( parseChanges
        , parseMatcher
        )
import Result
import Test exposing (..)


all =
    describe "parsing rules"
        [ matchers
        , changes
        , multiple
        ]


matchers =
    describe "matchers"
        [ test "any" <|
            \() ->
                Expect.equal
                    (Ok <| MatchAny [])
                    (parseMatcher "*")
        , test "id" <|
            \() ->
                Expect.equal
                    (Ok <| Match "cave" [])
                    (parseMatcher "cave")
        , test "uses full input" <|
            \() ->
                shouldFail "didn't parse full input"
                    (parseMatcher "cave asdf*=$")
        , test "tag" <|
            \() ->
                Expect.equal
                    (Ok <| MatchAny [ HasTag "dark" ])
                    (parseMatcher "*.dark")
        , test "stat =" <|
            \() ->
                Expect.equal
                    (Ok <| Match "PLAYER" [ HasStat "fear" EQ 5 ])
                    (parseMatcher "PLAYER.fear=5")
        , test "stat >" <|
            \() ->
                Expect.equal
                    (Ok <| Match "PLAYER" [ HasStat "fear" GT 5 ])
                    (parseMatcher "PLAYER.fear>5")
        , test "stat <" <|
            \() ->
                Expect.equal
                    (Ok <| Match "PLAYER" [ HasStat "fear" LT 5 ])
                    (parseMatcher "PLAYER.fear<5")
        , test "link just id" <|
            \() ->
                Expect.equal
                    (Ok <| Match "PLAYER" [ HasLink "location" (Match "CAVE" []) ])
                    (parseMatcher "PLAYER.location=CAVE")
        , test "link with $" <|
            \() ->
                Expect.equal
                    (Ok <| Match "PLAYER" [ HasLink "location" (Match "$" []) ])
                    (parseMatcher "PLAYER.location=$")
        , test "$ as selector (needed for conditional text)" <|
            \() ->
                Expect.equal
                    (Ok <| Match "$" [ HasTag "dark" ])
                    (parseMatcher "$.dark")
        , test "link missing parens" <|
            \() ->
                Expect.equal
                    (Ok <| Match "PLAYER" [ HasTag "dark", HasLink "location" (Match "CAVE" []) ])
                    (parseMatcher "PLAYER.location=CAVE.dark")
        , test "link with subquery" <|
            \() ->
                Expect.equal
                    (Ok <| Match "PLAYER" [ HasLink "location" (Match "CAVE" [ HasTag "dark" ]) ])
                    (parseMatcher "PLAYER.location=(CAVE.dark)")
        , test "link with subquery with MatchAny" <|
            \() ->
                Expect.equal
                    (Ok <| Match "PLAYER" [ HasLink "location" (MatchAny [ HasTag "dark", HasTag "location" ]) ])
                    (parseMatcher "PLAYER.location=(*.location.dark)")
        , test "link with subquery and extra tag" <|
            \() ->
                Expect.equal
                    (Ok <| Match "PLAYER" [ HasTag "blinded", HasLink "location" (Match "CAVE" [ HasTag "dark" ]) ])
                    (parseMatcher "PLAYER.location=(CAVE.dark).blinded")
        , test "link with nested subquery" <|
            \() ->
                Expect.equal
                    (Ok <| Match "PLAYER" [ HasLink "location" (MatchAny [ HasLink "homeTo" (Match "GOBLIN" []), HasTag "location" ]) ])
                    (parseMatcher "PLAYER.location=(*.location.homeTo=GOBLIN)")
        , test "link super nested" <|
            \() ->
                Expect.equal
                    (Ok <|
                        Match "PLAYER"
                            [ HasTag "scared"
                            , HasLink "location"
                                (MatchAny
                                    [ HasTag "dark"
                                    , HasLink "homeTo" (MatchAny [ HasTag "enemy" ])
                                    , HasTag "location"
                                    ]
                                )
                            ]
                    )
                    (parseMatcher "PLAYER.location=(*.location.homeTo=(*.enemy).dark).scared")
        , test "all together" <|
            \() ->
                Expect.equal
                    (Ok <|
                        Match "A"
                            [ HasTag "tag3"
                            , HasLink "link2" (Match "C" [])
                            , HasLink "link1" (Match "B" [])
                            , HasStat "stat2" GT 2
                            , HasStat "stat1" EQ 1
                            , HasTag "tag2"
                            , HasTag "tag1"
                            ]
                    )
                    (parseMatcher "A.tag1.tag2.stat1=1.stat2>2.link1=B.link2=C.tag3")
        , test "not" <|
            \() ->
                Expect.equal
                    (Ok <| MatchAny [ HasTag "scary", Not (HasTag "dark"), HasTag "location" ])
                    (parseMatcher "*.location.!dark.scary")
        , test "not 2" <|
            \() ->
                Expect.equal
                    (Ok <| Match "TORCH" [ Not (HasLink "location" (Match "PLAYER" [])) ])
                    (parseMatcher "TORCH.!location=PLAYER")
        , test "with spaces" <|
            \() ->
                Expect.equal
                    (Ok <| Match "PLAYER" [ HasTag "blinded", HasStat "fear" GT 2, HasLink "location" (Match "CAVE" []) ])
                    (parseMatcher "PLAYER .location=CAVE .fear>2 .blinded")
        , test "multiline" <|
            \() ->
                shouldFail "newlines not allowed"
                    (parseMatcher """PLAYER
                                        .location=CAVE
                                        .fear>2
                                        .blinded""")
        ]


changes =
    describe "changes"
        [ test "add tag" <|
            \() ->
                Expect.equal
                    (Ok <| Update "CAVE" [ AddTag "explored" ])
                    (parseChanges "CAVE.explored")
        , test "remove tag" <|
            \() ->
                Expect.equal
                    (Ok <| Update "GOBLIN" [ RemoveTag "sleeping" ])
                    (parseChanges "GOBLIN.-sleeping")
        , test "link" <|
            \() ->
                Expect.equal
                    (Ok <| Update "PLAYER" [ SetLink "location" "CAVE" ])
                    (parseChanges "PLAYER.location=CAVE")
        , test "set stat" <|
            \() ->
                Expect.equal
                    (Ok <| Update "PLAYER" [ SetStat "fear" 9 ])
                    (parseChanges "PLAYER.fear=9")
        , test "inc stat" <|
            \() ->
                Expect.equal
                    (Ok <| Update "PLAYER" [ IncStat "fear" 1 ])
                    (parseChanges "PLAYER.fear+1")
        , test "dec stat" <|
            \() ->
                Expect.equal
                    (Ok <| Update "PLAYER" [ DecStat "fear" 1 ])
                    (parseChanges "PLAYER.fear-1")
        , test "all together" <|
            \() ->
                Expect.equal
                    (Ok <|
                        Update "PLAYER"
                            [ AddTag "blinded"
                            , IncStat "fear" 2
                            , RemoveTag "safe"
                            , SetLink "location" "CAVE"
                            ]
                    )
                    (parseChanges "PLAYER.location=CAVE.-safe.fear+2.blinded")
        , test "spaces" <|
            \() ->
                Expect.equal
                    (Ok <|
                        Update "PLAYER"
                            [ AddTag "blinded"
                            , SetLink "location" "CAVE"
                            ]
                    )
                    (parseChanges "PLAYER  .location=CAVE  .blinded")
        , test "multiline disabled" <|
            \() ->
                shouldFail "multiline not allowed for changes"
                    (parseChanges """PLAYER
                                        .location=CAVE
                                        .blinded""")
        , test "update trigger" <|
            \() ->
                Expect.equal
                    (Ok <| Update "$" [ AddTag "explored" ])
                    (parseChanges "$.explored")
        , test "update link to trigger" <|
            \() ->
                Expect.equal
                    (Ok <| Update "PLAYER" [ SetLink "location" "$" ])
                    (parseChanges "PLAYER.location=$")
        , test "UpdateAll" <|
            \() ->
                Expect.equal
                    (Ok <| UpdateAll [ HasTag "suspect" ] [ RemoveTag "suspect" ])
                    (parseChanges "(*.suspect).-suspect")
        ]


multiple =
    describe "multiple"
        [ test "with parseMatcher (successful)" <|
            \() ->
                Expect.equal
                    (Ok <|
                        [ MatchAny [ HasLink "location" (Match "PLAYER" []), HasTag "light" ]
                        , Match "CAVE" [ HasTag "dark" ]
                        ]
                    )
                    (parseMultiple parseMatcher
                        [ "CAVE.dark"
                        , "*.light.location=PLAYER"
                        ]
                    )
        , test "unsuccessful" <|
            \() ->
                Expect.equal
                    (Err "expecting end at row 1, col 2")
                    (parseMultiple parseMatcher
                        [ "CAVE.dark"
                        , "*zzz.light.location=PLAYER"
                        ]
                    )
        ]


shouldFail message res =
    case res of
        Err _ ->
            Expect.pass

        _ ->
            Expect.fail message



{-

   ## QUERY exmaples (lists of matching entities)

   // Get a list of all of the locations:

       *.location

   // Get all items in the player's inventory:

       *.item.location=PLAYER

   // Test if the player has any item with enough illumination (if matches is not empty):

       *.item.location=PLAYER.illumination>5

   // Test if any characters in the cave are afraid (if matches is not empty):

       *.character.location=CAVE.fear>5

   // Test if the player is in the cave and afraid (either an empty query results, or the player entity)

       PLAYER.location=CAVE.fear>5

   RULES examples

      trigger: CAVE.!explored
      conditions:
      *.item.location=PLAYER.illumination>5
      changes:
      PLAYER.location=CAVE.fear+2
      CAVE.explored
      narrative: You can see a short ways into the cave, and bravely enter.  You hear an awful snoring sound...


      trigger: GOBLIN.sleeping
      changes:
      GOBLIN.-sleeping
      PLAYER.fear=9
      narrative: There's an old saying, "Let sleeping dogs lie."  That applies double when it comes to goblins.  Too late...

      // trigger match in conditional
      trigger: *.location
      conditions: *.enemy.location=$
      narrative: The {$.name} is too dangerous to enter now...
      // note, there is no way to reference the name/description of the enemy matcher


      // moving around
      trigger: *.location
      changes: PLAYER.location=$

      // picking stuff up
      trigger: *.item.!location=PLAYER
      changes: $.location=PLAYER
      narrative: This might be useful.

      nested (PLAYER.location=(*.dark))
-}