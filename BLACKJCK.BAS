' =====================================================================
'  BLACKJACK DELUXE VGA                                    Version 1.0
'  A casino-style blackjack game for Microsoft QBASIC 1.1
'  SCREEN 12 (640x480, 16 colors) - no external files required
'
'  Load this file into QBASIC.EXE and press F5 to play.
'
'  Sections:  Initialization / Graphics / Cards / Dealer /
'             Gameplay / Money / Statistics / Sound
' =====================================================================
DEFINT A-Z

DECLARE SUB TitleScreen ()
DECLARE SUB DrawTable ()
DECLARE SUB DrawDealer (cx%, fy%)
DECLARE SUB DrawChips (x%, y%, clr%)
DECLARE SUB DrawCard (x%, y%, c%)
DECLARE SUB DrawBackCard (x%, y%)
DECLARE SUB DrawSuit (cx%, cy%, s%, size%, clr%)
DECLARE SUB BigLetter (ch$, x%, y%, sc%, clr%)
DECLARE SUB BigText (s$, x%, y%, sc%, clr%)
DECLARE SUB AnimateDeal (dx%, dy%)
DECLARE SUB DealOne (who%, hidden%)
DECLARE SUB ShuffleDeck ()
DECLARE SUB PlayHand ()
DECLARE SUB GetBet ()
DECLARE SUB Settle (outcome%, amt&, m$)
DECLARE SUB DealerSay (m$)
DECLARE SUB PromptLine (m$)
DECLARE SUB ClearPrompt ()
DECLARE SUB ShowTotals (showHole%)
DECLARE SUB ShowStatus ()
DECLARE SUB ClearTableArea ()
DECLARE SUB PrintStats (row%)
DECLARE SUB FarewellScreen ()
DECLARE SUB Delay (sec!)
DECLARE SUB SndDeal ()
DECLARE SUB SndChip ()
DECLARE SUB SndWin ()
DECLARE SUB SndLose ()
DECLARE SUB SndBust ()
DECLARE SUB SndBlackjack ()
DECLARE SUB SndPush ()
DECLARE SUB SndShuffle ()
DECLARE FUNCTION HandValue% (who%)
DECLARE FUNCTION NextCard% ()
DECLARE FUNCTION GetKey$ ()
DECLARE FUNCTION GetNum& ()
DECLARE FUNCTION KeyWait% (sec!)
DECLARE FUNCTION GameOver% ()

' ------------------------- INITIALIZATION ----------------------------

TYPE StatsType
   played AS INTEGER
   won AS INTEGER
   lost AS INTEGER
   pushed AS INTEGER
   best AS LONG
END TYPE

DIM SHARED deck(1 TO 52)            ' the deck (1-52)
DIM SHARED deckPos                  ' next card index into deck()
DIM SHARED pHand(1 TO 12)           ' player hand
DIM SHARED pCount                   ' cards in player hand
DIM SHARED dHand(1 TO 12)           ' dealer hand
DIM SHARED dCount                   ' cards in dealer hand
DIM SHARED bankroll AS LONG         ' player money
DIM SHARED bet AS LONG              ' current wager
DIM SHARED st AS StatsType          ' session statistics

' Card encoding: c = 1..52
'   rank = ((c-1) MOD 13) + 1   (1=Ace ... 13=King)
'   suit = (c-1) \ 13           (0=Hearts 1=Diamonds 2=Clubs 3=Spades)

RANDOMIZE TIMER
SCREEN 12

TitleScreen

showFarewell = 0
playing = 1
DO WHILE playing = 1
   bankroll = 1000
   bet = 0
   st.played = 0: st.won = 0: st.lost = 0: st.pushed = 0
   st.best = 1000
   ShuffleDeck
   DrawTable
   DO
      PlayHand
      IF bankroll <= 0 THEN
         Delay 1.5
         IF GameOver = 1 THEN
            EXIT DO                 ' restart with fresh bankroll
         ELSE
            playing = 0
            EXIT DO
         END IF
      ELSE
         PromptLine "PRESS ANY KEY FOR NEXT HAND OR (Q) TO QUIT..."
         k$ = GetKey$
         IF k$ = "Q" THEN
            playing = 0
            showFarewell = 1
            EXIT DO
         END IF
      END IF
   LOOP
LOOP

IF showFarewell = 1 THEN FarewellScreen
SCREEN 0
WIDTH 80, 25
CLS
END

' --------------------------- GAMEPLAY --------------------------------

SUB PlayHand
   ' One complete hand: bet, deal, player turn, dealer turn, payout.
   IF deckPos > 30 THEN
      DealerSay "Shuffling the deck..."
      SndShuffle
      ShuffleDeck
      Delay .8
   END IF
   ClearTableArea
   ShowStatus
   DealerSay "Place your bet"
   GetBet
   SndChip

   pCount = 0: dCount = 0
   DealOne 1, 0
   DealOne 2, 0
   DealOne 1, 0
   DealOne 2, 1                     ' dealer hole card stays hidden
   ShowTotals 0

   pv = HandValue(1)
   dv = HandValue(2)
   pBJ = 0: IF pv = 21 THEN pBJ = 1
   dBJ = 0: IF dv = 21 THEN dBJ = 1

   ' ---- insurance offer when dealer shows an ace ----
   ins& = 0
   upRank = ((dHand(1) - 1) MOD 13) + 1
   IF upRank = 1 AND bankroll >= bet + bet \ 2 AND bet >= 2 THEN
      DealerSay "Insurance?"
      PromptLine "DEALER SHOWS AN ACE. INSURANCE? (Y/N)"
      DO
         k$ = GetKey$
      LOOP UNTIL k$ = "Y" OR k$ = "N"
      IF k$ = "Y" THEN ins& = bet \ 2: SndChip
      ClearPrompt
   END IF

   ' ---- dealer blackjack ends the hand immediately ----
   IF dBJ = 1 THEN
      DrawCard 104, 128, dHand(2)
      ShowTotals 1
      IF ins& > 0 THEN
         bankroll = bankroll + 2 * ins&
         PromptLine "INSURANCE PAYS 2 TO 1!"
         Delay 1.5
         ClearPrompt
      END IF
      IF pBJ = 1 THEN
         Settle 0, 0, "Push"
      ELSE
         Settle -1, bet, "Dealer wins"
      END IF
      EXIT SUB
   END IF
   IF ins& > 0 THEN
      bankroll = bankroll - ins&
      ShowStatus
      PromptLine "NO DEALER BLACKJACK. INSURANCE LOST."
      Delay 1.5
      ClearPrompt
   END IF

   ' ---- player blackjack pays 3:2 ----
   IF pBJ = 1 THEN
      Settle 2, bet * 3 \ 2, "Blackjack!"
      EXIT SUB
   END IF

   ' ---- player turn ----
   first = 1
   DO
      pv = HandValue(1)
      ShowTotals 0
      IF pv >= 21 THEN EXIT DO
      DealerSay "Hit or Stand?"
      p$ = "(H)IT  (S)TAND"
      IF first = 1 AND bankroll >= bet * 2 THEN p$ = p$ + "  (D)OUBLE"
      IF first = 1 THEN p$ = p$ + "  (R) SURRENDER"
      PromptLine p$
      DO
         k$ = GetKey$
         ok = 0
         IF k$ = "H" OR k$ = "S" THEN ok = 1
         IF k$ = "D" AND first = 1 AND bankroll >= bet * 2 THEN ok = 1
         IF k$ = "R" AND first = 1 THEN ok = 1
      LOOP UNTIL ok = 1
      ClearPrompt
      SELECT CASE k$
      CASE "H"
         DealOne 1, 0
         first = 0
      CASE "S"
         EXIT DO
      CASE "D"
         bet = bet * 2
         ShowStatus
         DealerSay "Doubling down!"
         DealOne 1, 0
         EXIT DO
      CASE "R"
         Settle -1, bet \ 2, "Surrendered"
         EXIT SUB
      END SELECT
   LOOP

   pv = HandValue(1)
   ShowTotals 0
   IF pv > 21 THEN
      DrawCard 104, 128, dHand(2)
      ShowTotals 1
      Settle -2, bet, "Bust! Dealer wins"
      EXIT SUB
   END IF

   ' ---- dealer turn: reveal hole card, hit to 17, stand on all 17 ----
   DealerSay "Dealer's turn..."
   DrawCard 104, 128, dHand(2)
   SOUND 700, .5
   ShowTotals 1
   Delay 1.2
   DO WHILE HandValue(2) < 17
      DealOne 2, 0
      ShowTotals 1
      Delay .6
   LOOP

   ' ---- payout ----
   dv = HandValue(2)
   IF dv > 21 THEN
      Settle 1, bet, "Dealer busts! You win!"
   ELSEIF dv > pv THEN
      Settle -1, bet, "Dealer wins"
   ELSEIF dv < pv THEN
      Settle 1, bet, "You win!"
   ELSE
      Settle 0, 0, "Push"
   END IF
END SUB

SUB DealOne (who, hidden)
   ' Draws the next card from the deck into a hand and animates it.
   c = NextCard
   IF who = 1 THEN
      pCount = pCount + 1
      pHand(pCount) = c
      x = 40 + (pCount - 1) * 64
      y = 304
   ELSE
      dCount = dCount + 1
      dHand(dCount) = c
      x = 40 + (dCount - 1) * 64
      y = 128
   END IF
   SndDeal
   AnimateDeal x, y
   IF hidden = 1 THEN
      DrawBackCard x, y
   ELSE
      DrawCard x, y, c
   END IF
END SUB

' ---------------------------- MONEY ----------------------------------

SUB GetBet
   ' Prompts for a wager between $1 and the bankroll, with validation.
   DO
      ClearPrompt
      COLOR 15
      LOCATE 29, 3
      PRINT "ENTER YOUR BET ($1 - $"; LTRIM$(STR$(bankroll)); "): ";
      b& = GetNum&
      IF b& >= 1 AND b& <= bankroll THEN
         bet = b&
         ClearPrompt
         ShowStatus
         EXIT SUB
      END IF
      SOUND 150, 2
   LOOP
END SUB

FUNCTION GetNum&
   ' Reads digits at the current cursor, ENTER accepts, BACKSPACE edits.
   s$ = ""
   DO
      k$ = GetKey$
      IF k$ = CHR$(13) AND LEN(s$) > 0 THEN EXIT DO
      IF k$ = CHR$(8) AND LEN(s$) > 0 THEN
         s$ = LEFT$(s$, LEN(s$) - 1)
         PRINT CHR$(29); " "; CHR$(29);
      ELSEIF k$ >= "0" AND k$ <= "9" AND LEN(s$) < 7 THEN
         s$ = s$ + k$
         PRINT k$;
      END IF
   LOOP
   GetNum& = VAL(s$)
END FUNCTION

SUB Settle (outcome, amt&, m$)
   ' Applies the result of a hand to the bankroll and statistics.
   ' outcome:  2=blackjack  1=win  0=push  -1=loss  -2=bust
   SELECT CASE outcome
   CASE 2
      bankroll = bankroll + amt&
      st.won = st.won + 1
      SndBlackjack
   CASE 1
      bankroll = bankroll + amt&
      st.won = st.won + 1
      SndWin
   CASE 0
      st.pushed = st.pushed + 1
      SndPush
   CASE -1
      bankroll = bankroll - amt&
      st.lost = st.lost + 1
      SndLose
   CASE -2
      bankroll = bankroll - amt&
      st.lost = st.lost + 1
      SndBust
   END SELECT
   st.played = st.played + 1
   IF bankroll > st.best THEN st.best = bankroll
   DealerSay m$
   ShowStatus
END SUB

SUB ShowStatus
   COLOR 14
   LOCATE 28, 3
   PRINT "BANKROLL: $"; LTRIM$(STR$(bankroll));
   PRINT "      BET: $"; LTRIM$(STR$(bet)); "          ";
END SUB

SUB ShowTotals (showHole)
   COLOR 15
   LOCATE 8, 3
   IF showHole = 1 THEN
      PRINT "DEALER:"; HandValue(2); "  ";
   ELSE
      PRINT "DEALER: ??   ";
   END IF
   LOCATE 25, 3
   PRINT "PLAYER:"; HandValue(1); "  ";
END SUB

SUB PromptLine (m$)
   ClearPrompt
   COLOR 15
   LOCATE 29, 3: PRINT LEFT$(m$, 75);
END SUB

SUB ClearPrompt
   LOCATE 29, 2: PRINT SPACE$(77);
END SUB

' ---------------------------- CARDS ----------------------------------

SUB ShuffleDeck
   ' Fisher-Yates shuffle of a fresh 52 card deck.
   FOR i = 1 TO 52
      deck(i) = i
   NEXT
   FOR i = 52 TO 2 STEP -1
      j = INT(RND * i) + 1
      SWAP deck(i), deck(j)
   NEXT
   deckPos = 0
END SUB

FUNCTION NextCard
   deckPos = deckPos + 1
   IF deckPos > 52 THEN
      ShuffleDeck                   ' emergency reshuffle (should not occur)
      deckPos = 1
   END IF
   NextCard = deck(deckPos)
END FUNCTION

FUNCTION HandValue (who)
   ' Best blackjack total for a hand; aces count 11 then drop to 1.
   t = 0: aces = 0
   IF who = 1 THEN n = pCount ELSE n = dCount
   FOR i = 1 TO n
      IF who = 1 THEN c = pHand(i) ELSE c = dHand(i)
      r = ((c - 1) MOD 13) + 1
      IF r = 1 THEN
         aces = aces + 1
         t = t + 11
      ELSEIF r > 10 THEN
         t = t + 10
      ELSE
         t = t + r
      END IF
   NEXT
   DO WHILE t > 21 AND aces > 0
      t = t - 10
      aces = aces - 1
   LOOP
   HandValue = t
END FUNCTION

SUB DrawCard (x, y, c)
   ' Renders a 56x80 card face at pixel (x, y).
   r = ((c - 1) MOD 13) + 1
   s = (c - 1) \ 13
   IF s < 2 THEN clr = 4 ELSE clr = 0
   SELECT CASE r
   CASE 1: rn$ = "A"
   CASE 11: rn$ = "J"
   CASE 12: rn$ = "Q"
   CASE 13: rn$ = "K"
   CASE ELSE: rn$ = LTRIM$(STR$(r))
   END SELECT
   LINE (x, y)-(x + 55, y + 79), 15, BF
   LINE (x, y)-(x + 55, y + 79), 0, B
   PSET (x + 1, y + 1), 0: PSET (x + 54, y + 1), 0
   PSET (x + 1, y + 78), 0: PSET (x + 54, y + 78), 0
   BigText rn$, x + 3, y + 3, 1, clr
   DrawSuit x + 8, y + 17, s, 4, clr
   w = LEN(rn$) * 6 - 1
   BigText rn$, x + 52 - w, y + 70, 1, clr
   DrawSuit x + 47, y + 60, s, 4, clr
   IF r > 10 THEN
      BigText rn$, x + 21, y + 24, 3, clr
      DrawSuit x + 28, y + 56, s, 6, clr
   ELSE
      DrawSuit x + 28, y + 40, s, 10, clr
   END IF
END SUB

SUB DrawBackCard (x, y)
   ' Renders the blue patterned card back at pixel (x, y).
   LINE (x, y)-(x + 55, y + 79), 15, BF
   LINE (x, y)-(x + 55, y + 79), 0, B
   LINE (x + 3, y + 3)-(x + 52, y + 76), 1, BF
   LINE (x + 3, y + 3)-(x + 52, y + 76), 15, B
   FOR yy = y + 13 TO y + 70 STEP 14
      FOR xx = x + 14 TO x + 45 STEP 14
         LINE (xx - 4, yy)-(xx, yy - 4), 9
         LINE (xx, yy - 4)-(xx + 4, yy), 9
         LINE (xx + 4, yy)-(xx, yy + 4), 9
         LINE (xx, yy + 4)-(xx - 4, yy), 9
      NEXT
   NEXT
   PSET (x + 1, y + 1), 0: PSET (x + 54, y + 1), 0
   PSET (x + 1, y + 78), 0: PSET (x + 54, y + 78), 0
END SUB

SUB DrawSuit (cx, cy, s, size, clr)
   ' Draws a filled suit symbol centered near (cx, cy).
   ' s: 0=hearts 1=diamonds 2=clubs 3=spades   size: half-width
   SELECT CASE s
   CASE 0                           ' hearts
      r = size \ 2
      IF r < 2 THEN r = 2
      CIRCLE (cx - r, cy - r), r, clr
      PAINT (cx - r, cy - r), clr, clr
      CIRCLE (cx + r, cy - r), r, clr
      PAINT (cx + r, cy - r), clr, clr
      LINE (cx - 2 * r, cy - r)-(cx + 2 * r, cy - r), clr
      LINE (cx + 2 * r, cy - r)-(cx, cy + 2 * r), clr
      LINE (cx, cy + 2 * r)-(cx - 2 * r, cy - r), clr
      PAINT (cx, cy), clr, clr
   CASE 1                           ' diamonds
      w = size: h = size + size \ 2
      IF w < 2 THEN w = 2
      IF h < 3 THEN h = 3
      LINE (cx, cy - h)-(cx + w, cy), clr
      LINE (cx + w, cy)-(cx, cy + h), clr
      LINE (cx, cy + h)-(cx - w, cy), clr
      LINE (cx - w, cy)-(cx, cy - h), clr
      PAINT (cx, cy), clr, clr
   CASE 2                           ' clubs
      r = size \ 2 + 1
      CIRCLE (cx, cy - r), r, clr
      PAINT (cx, cy - r), clr, clr
      CIRCLE (cx - r, cy + r \ 2), r, clr
      PAINT (cx - r, cy + r \ 2), clr, clr
      CIRCLE (cx + r, cy + r \ 2), r, clr
      PAINT (cx + r, cy + r \ 2), clr, clr
      LINE (cx - 1, cy)-(cx + 1, cy + 2 * r), clr, BF
   CASE 3                           ' spades
      r = size \ 2
      IF r < 2 THEN r = 2
      CIRCLE (cx - r, cy + r), r, clr
      PAINT (cx - r, cy + r), clr, clr
      CIRCLE (cx + r, cy + r), r, clr
      PAINT (cx + r, cy + r), clr, clr
      LINE (cx - 2 * r, cy + r)-(cx + 2 * r, cy + r), clr
      LINE (cx + 2 * r, cy + r)-(cx, cy - 2 * r), clr
      LINE (cx, cy - 2 * r)-(cx - 2 * r, cy + r), clr
      PAINT (cx, cy), clr, clr
      LINE (cx - 1, cy + r)-(cx + 1, cy + 2 * r + 2), clr, BF
   END SELECT
END SUB

SUB AnimateDeal (dx, dy)
   ' Slides a card back from the deck pile to its destination slot.
   px = 568: py = 224
   DrawBackCard px, py
   DO WHILE px > dx
      LINE (px, py)-(px + 55, py + 79), 2, BF
      px = px - 24
      IF px < dx THEN px = dx
      DrawBackCard px, py
      Delay .015
   LOOP
   DO WHILE py <> dy
      LINE (px, py)-(px + 55, py + 79), 2, BF
      IF dy < py THEN
         py = py - 24
         IF py < dy THEN py = dy
      ELSE
         py = py + 24
         IF py > dy THEN py = dy
      END IF
      DrawBackCard px, py
      Delay .015
   LOOP
   DrawBackCard 568, 224            ' restore the deck pile
END SUB

' --------------------------- GRAPHICS --------------------------------

SUB BigLetter (ch$, x, y, sc, clr)
   ' Draws one character from a 5x7 bitmap font, scaled by sc.
   ' Background is left untouched (transparent lettering).
   DIM p(1 TO 7)
   SELECT CASE ch$
   CASE "A": p(1) = 14: p(2) = 17: p(3) = 17: p(4) = 31: p(5) = 17: p(6) = 17: p(7) = 17
   CASE "B": p(1) = 30: p(2) = 17: p(3) = 17: p(4) = 30: p(5) = 17: p(6) = 17: p(7) = 30
   CASE "C": p(1) = 14: p(2) = 17: p(3) = 16: p(4) = 16: p(5) = 16: p(6) = 17: p(7) = 14
   CASE "D": p(1) = 30: p(2) = 17: p(3) = 17: p(4) = 17: p(5) = 17: p(6) = 17: p(7) = 30
   CASE "E": p(1) = 31: p(2) = 16: p(3) = 16: p(4) = 30: p(5) = 16: p(6) = 16: p(7) = 31
   CASE "F": p(1) = 31: p(2) = 16: p(3) = 16: p(4) = 30: p(5) = 16: p(6) = 16: p(7) = 16
   CASE "G": p(1) = 14: p(2) = 17: p(3) = 16: p(4) = 23: p(5) = 17: p(6) = 17: p(7) = 14
   CASE "H": p(1) = 17: p(2) = 17: p(3) = 17: p(4) = 31: p(5) = 17: p(6) = 17: p(7) = 17
   CASE "I": p(1) = 14: p(2) = 4: p(3) = 4: p(4) = 4: p(5) = 4: p(6) = 4: p(7) = 14
   CASE "J": p(1) = 7: p(2) = 2: p(3) = 2: p(4) = 2: p(5) = 2: p(6) = 18: p(7) = 12
   CASE "K": p(1) = 17: p(2) = 18: p(3) = 20: p(4) = 24: p(5) = 20: p(6) = 18: p(7) = 17
   CASE "L": p(1) = 16: p(2) = 16: p(3) = 16: p(4) = 16: p(5) = 16: p(6) = 16: p(7) = 31
   CASE "M": p(1) = 17: p(2) = 27: p(3) = 21: p(4) = 21: p(5) = 17: p(6) = 17: p(7) = 17
   CASE "N": p(1) = 17: p(2) = 25: p(3) = 21: p(4) = 19: p(5) = 17: p(6) = 17: p(7) = 17
   CASE "O": p(1) = 14: p(2) = 17: p(3) = 17: p(4) = 17: p(5) = 17: p(6) = 17: p(7) = 14
   CASE "P": p(1) = 30: p(2) = 17: p(3) = 17: p(4) = 30: p(5) = 16: p(6) = 16: p(7) = 16
   CASE "Q": p(1) = 14: p(2) = 17: p(3) = 17: p(4) = 17: p(5) = 21: p(6) = 18: p(7) = 13
   CASE "R": p(1) = 30: p(2) = 17: p(3) = 17: p(4) = 30: p(5) = 20: p(6) = 18: p(7) = 17
   CASE "S": p(1) = 14: p(2) = 17: p(3) = 16: p(4) = 14: p(5) = 1: p(6) = 17: p(7) = 14
   CASE "T": p(1) = 31: p(2) = 4: p(3) = 4: p(4) = 4: p(5) = 4: p(6) = 4: p(7) = 4
   CASE "U": p(1) = 17: p(2) = 17: p(3) = 17: p(4) = 17: p(5) = 17: p(6) = 17: p(7) = 14
   CASE "V": p(1) = 17: p(2) = 17: p(3) = 17: p(4) = 17: p(5) = 17: p(6) = 10: p(7) = 4
   CASE "W": p(1) = 17: p(2) = 17: p(3) = 17: p(4) = 21: p(5) = 21: p(6) = 21: p(7) = 10
   CASE "X": p(1) = 17: p(2) = 17: p(3) = 10: p(4) = 4: p(5) = 10: p(6) = 17: p(7) = 17
   CASE "Y": p(1) = 17: p(2) = 17: p(3) = 10: p(4) = 4: p(5) = 4: p(6) = 4: p(7) = 4
   CASE "Z": p(1) = 31: p(2) = 1: p(3) = 2: p(4) = 4: p(5) = 8: p(6) = 16: p(7) = 31
   CASE "0": p(1) = 14: p(2) = 17: p(3) = 19: p(4) = 21: p(5) = 25: p(6) = 17: p(7) = 14
   CASE "1": p(1) = 4: p(2) = 12: p(3) = 4: p(4) = 4: p(5) = 4: p(6) = 4: p(7) = 14
   CASE "2": p(1) = 14: p(2) = 17: p(3) = 1: p(4) = 2: p(5) = 4: p(6) = 8: p(7) = 31
   CASE "3": p(1) = 30: p(2) = 1: p(3) = 1: p(4) = 14: p(5) = 1: p(6) = 1: p(7) = 30
   CASE "4": p(1) = 2: p(2) = 6: p(3) = 10: p(4) = 18: p(5) = 31: p(6) = 2: p(7) = 2
   CASE "5": p(1) = 31: p(2) = 16: p(3) = 30: p(4) = 1: p(5) = 1: p(6) = 17: p(7) = 14
   CASE "6": p(1) = 6: p(2) = 8: p(3) = 16: p(4) = 30: p(5) = 17: p(6) = 17: p(7) = 14
   CASE "7": p(1) = 31: p(2) = 1: p(3) = 2: p(4) = 4: p(5) = 8: p(6) = 8: p(7) = 8
   CASE "8": p(1) = 14: p(2) = 17: p(3) = 17: p(4) = 14: p(5) = 17: p(6) = 17: p(7) = 14
   CASE "9": p(1) = 14: p(2) = 17: p(3) = 17: p(4) = 15: p(5) = 1: p(6) = 2: p(7) = 12
   CASE ELSE
      EXIT SUB
   END SELECT
   FOR r = 1 TO 7
      m = 16
      FOR c = 0 TO 4
         IF (p(r) AND m) <> 0 THEN
            LINE (x + c * sc, y + (r - 1) * sc)-(x + c * sc + sc - 1, y + (r - 1) * sc + sc - 1), clr, BF
         END IF
         m = m \ 2
      NEXT
   NEXT
END SUB

SUB BigText (s$, x, y, sc, clr)
   ' Draws a string in the scalable bitmap font.  Advance = 6*sc per char.
   px = x
   FOR i = 1 TO LEN(s$)
      ch$ = MID$(s$, i, 1)
      IF ch$ <> " " THEN BigLetter ch$, px, y, sc, clr
      px = px + 6 * sc
   NEXT
END SUB

' ---------------------------- DEALER ----------------------------------

SUB DrawDealer (cx, fy)
   ' Cartoon casino dealer.  cx = center x, fy = face center y.
   ' jacket
   LINE (cx - 34, fy + 16)-(cx + 34, fy + 62), 0, BF
   ' shirt
   LINE (cx - 7, fy + 16)-(cx + 7, fy + 44), 15, BF
   ' lapels
   LINE (cx - 7, fy + 16)-(cx - 16, fy + 34), 8
   LINE (cx + 7, fy + 16)-(cx + 16, fy + 34), 8
   ' hair
   CIRCLE (cx, fy - 8), 19, 6
   PAINT (cx, fy - 8), 6, 6
   ' face
   CIRCLE (cx, fy), 18, 0
   PAINT (cx, fy), 7, 0
   ' eyes
   CIRCLE (cx - 7, fy - 4), 2, 0
   PAINT (cx - 7, fy - 4), 0, 0
   CIRCLE (cx + 7, fy - 4), 2, 0
   PAINT (cx + 7, fy - 4), 0, 0
   ' eyebrows
   LINE (cx - 10, fy - 9)-(cx - 4, fy - 9), 0
   LINE (cx + 4, fy - 9)-(cx + 10, fy - 9), 0
   ' nose
   LINE (cx, fy - 2)-(cx - 2, fy + 4), 0
   LINE (cx - 2, fy + 4)-(cx, fy + 4), 0
   ' smile
   CIRCLE (cx, fy + 6), 8, 0, 3.6, 5.8
   ' bow tie
   LINE (cx - 12, fy + 18)-(cx - 2, fy + 26), 4, BF
   LINE (cx + 2, fy + 18)-(cx + 12, fy + 26), 4, BF
   LINE (cx - 2, fy + 20)-(cx + 2, fy + 24), 4, BF
   ' jacket buttons
   PSET (cx, fy + 50), 15
   PSET (cx, fy + 56), 15
END SUB

SUB DrawChips (x, y, clr)
   ' A stack of five casino chips drawn with flattened circles.
   FOR i = 0 TO 4
      CIRCLE (x, y - i * 5), 14, clr, , , .35
      PAINT (x, y - i * 5), clr, clr
   NEXT
   CIRCLE (x, y - 20), 14, 15, , , .35
END SUB

SUB DrawTable
   ' Paints the casino table and all permanent fixtures.
   CLS
   LINE (0, 0)-(639, 479), 2, BF
   LINE (2, 2)-(637, 477), 14, B
   LINE (5, 5)-(634, 474), 14, B
   COLOR 14
   LOCATE 2, 4: PRINT "* BLACKJACK DELUXE *";
   DrawDealer 320, 48
   DealerSay "Welcome to the table!"
   LINE (6, 428)-(633, 428), 14
   LINE (6, 431)-(633, 473), 0, BF
   ClearTableArea
   ShowStatus
END SUB

SUB ClearTableArea
   ' Clears the playing felt between the dealer art and the status bar.
   LINE (8, 112)-(631, 424), 2, BF
   DrawBackCard 568, 224
   COLOR 7
   LOCATE 14, 72: PRINT "DECK";
END SUB

SUB DealerSay (m$)
   ' Dealer speech box at the top right of the screen.
   LINE (392, 16)-(630, 72), 0, BF
   LINE (392, 16)-(630, 72), 15, B
   LINE (392, 44)-(356, 56), 15
   t$ = LEFT$(m$, 28)
   c = 51 + (28 - LEN(t$)) \ 2
   COLOR 15
   LOCATE 3, c: PRINT t$;
END SUB

' ---------------------------- SCREENS ---------------------------------

SUB TitleScreen
   ' Shareware-style title screen with big lettering, cards and dealer.
   CLS
   LINE (4, 4)-(635, 475), 14, B
   LINE (8, 8)-(631, 471), 14, B
   BigText "BLACKJACK", 164, 30, 6, 4
   BigText "BLACKJACK", 161, 27, 6, 14
   BigText "DELUXE", 218, 82, 6, 4
   BigText "DELUXE", 215, 79, 6, 14
   COLOR 15
   LOCATE 9, 32: PRINT "A VGA CASINO GAME";
   COLOR 7
   LOCATE 10, 32: PRINT "WRITTEN IN QBASIC";
   ' display hand: ace of spades, king of hearts, queen of diamonds
   DrawCard 248, 184, 40
   DrawCard 312, 196, 13
   DrawCard 376, 184, 25
   DrawDealer 120, 220
   DrawChips 520, 250, 4
   DrawChips 556, 262, 9
   DrawChips 488, 268, 15
   COLOR 7
   LOCATE 22, 26: PRINT "(C) 1992 GREEN FELT SOFTWARE";
   LOCATE 23, 29: PRINT "SHAREWARE EDITION 1.0";
   SOUND 392, 2: SOUND 523, 2: SOUND 659, 2: SOUND 784, 5
   DO
      COLOR 14
      LOCATE 27, 26: PRINT "PRESS ANY KEY TO ENTER CASINO";
      IF KeyWait(.6) = 1 THEN EXIT DO
      COLOR 8
      LOCATE 27, 26: PRINT "PRESS ANY KEY TO ENTER CASINO";
      IF KeyWait(.3) = 1 THEN EXIT DO
   LOOP
END SUB

FUNCTION GameOver
   ' Bankroll hit zero.  Returns 1 to play again, 0 to quit.
   SOUND 200, 4: SOUND 150, 4: SOUND 100, 8
   CLS
   BigText "GAME OVER", 190, 83, 5, 8
   BigText "GAME OVER", 187, 80, 5, 4
   BigText "CASINO WINS", 224, 150, 3, 14
   PrintStats 14
   COLOR 15
   LOCATE 22, 30: PRINT "PLAY AGAIN? (Y/N)";
   DO
      k$ = GetKey$
   LOOP UNTIL k$ = "Y" OR k$ = "N"
   IF k$ = "Y" THEN GameOver = 1 ELSE GameOver = 0
END FUNCTION

SUB FarewellScreen
   ' Shown when the player cashes out with money remaining.
   CLS
   BigText "CASHING OUT", 192, 62, 4, 8
   BigText "CASHING OUT", 190, 60, 4, 14
   PrintStats 12
   COLOR 10
   LOCATE 19, 25: PRINT "YOU LEAVE THE CASINO WITH $"; LTRIM$(STR$(bankroll));
   COLOR 7
   LOCATE 22, 31: PRINT "THANKS FOR PLAYING!";
   LOCATE 24, 32: PRINT "PRESS ANY KEY...";
   SndWin
   k$ = GetKey$
END SUB

' -------------------------- STATISTICS --------------------------------

SUB PrintStats (row)
   COLOR 15
   LOCATE row, 28: PRINT "HANDS PLAYED ......"; st.played;
   LOCATE row + 1, 28: PRINT "HANDS WON ........."; st.won;
   LOCATE row + 2, 28: PRINT "HANDS LOST ........"; st.lost;
   LOCATE row + 3, 28: PRINT "PUSHES ............"; st.pushed;
   LOCATE row + 4, 28: PRINT "LARGEST BANKROLL .. $"; LTRIM$(STR$(st.best));
END SUB

' --------------------------- UTILITIES ---------------------------------

SUB Delay (sec!)
   ' Waits sec! seconds using TIMER; bails out across midnight rollover.
   t! = TIMER
   DO
      IF TIMER < t! THEN EXIT DO
   LOOP UNTIL TIMER - t! >= sec!
END SUB

FUNCTION GetKey$
   ' Waits for a keypress and returns it uppercased.
   DO
      k$ = INKEY$
   LOOP UNTIL k$ <> ""
   GetKey$ = UCASE$(LEFT$(k$, 1))
END FUNCTION

FUNCTION KeyWait (sec!)
   ' Waits up to sec! seconds; returns 1 if a key was pressed.
   t! = TIMER
   KeyWait = 0
   DO
      IF INKEY$ <> "" THEN
         KeyWait = 1
         EXIT FUNCTION
      END IF
      IF TIMER < t! THEN EXIT DO
   LOOP UNTIL TIMER - t! >= sec!
END FUNCTION

' ----------------------------- SOUND -----------------------------------

SUB SndDeal
   SOUND 880, .3
   SOUND 660, .2
END SUB

SUB SndChip
   SOUND 1320, .5
   SOUND 1760, .5
END SUB

SUB SndWin
   SOUND 523, 1.5
   SOUND 659, 1.5
   SOUND 784, 3
END SUB

SUB SndLose
   SOUND 330, 2
   SOUND 262, 3
END SUB

SUB SndBust
   SOUND 220, 2
   SOUND 165, 2
   SOUND 110, 4
END SUB

SUB SndBlackjack
   SOUND 523, 1
   SOUND 659, 1
   SOUND 784, 1
   SOUND 1047, 4
END SUB

SUB SndPush
   SOUND 440, 2
   SOUND 440, 2
END SUB

SUB SndShuffle
   FOR f = 400 TO 900 STEP 100
      SOUND f, .4
   NEXT
END SUB
