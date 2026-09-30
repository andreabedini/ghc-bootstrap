{-# OPTIONS_GHC -w #-}
{-# OPTIONS_GHC -w #-}
module Parser (ourParser,AbsSyn) where
import ParseMonad
import AbsSyn
import Lexer
import Control.Applicative(Applicative(..))
import Control.Monad (ap)

-- parser produced by Happy Version 1.19.5

data HappyAbsSyn 
	= HappyTerminal (Token)
	| HappyErrorToken Int
	| HappyAbsSyn4 (AbsSyn)
	| HappyAbsSyn5 ([Rule])
	| HappyAbsSyn6 (Rule)
	| HappyAbsSyn7 ([String])
	| HappyAbsSyn9 ([Prod])
	| HappyAbsSyn10 (Prod)
	| HappyAbsSyn11 (Term)
	| HappyAbsSyn12 ([Term])
	| HappyAbsSyn15 (Maybe String)
	| HappyAbsSyn16 ([Directive String])
	| HappyAbsSyn17 (Directive String)
	| HappyAbsSyn19 ([(String,String)])
	| HappyAbsSyn20 ((String,String))

{- to allow type-synonyms as our monads (likely
 - with explicitly-specified bind and return)
 - in Haskell98, it seems that with
 - /type M a = .../, then /(HappyReduction M)/
 - is not allowed.  But Happy is a
 - code-generator that can just substitute it.
type HappyReduction m = 
	   Int 
	-> (Token)
	-> HappyState (Token) (HappyStk HappyAbsSyn -> m HappyAbsSyn)
	-> [HappyState (Token) (HappyStk HappyAbsSyn -> m HappyAbsSyn)] 
	-> HappyStk HappyAbsSyn 
	-> m HappyAbsSyn
-}

action_0,
 action_1,
 action_2,
 action_3,
 action_4,
 action_5,
 action_6,
 action_7,
 action_8,
 action_9,
 action_10,
 action_11,
 action_12,
 action_13,
 action_14,
 action_15,
 action_16,
 action_17,
 action_18,
 action_19,
 action_20,
 action_21,
 action_22,
 action_23,
 action_24,
 action_25,
 action_26,
 action_27,
 action_28,
 action_29,
 action_30,
 action_31,
 action_32,
 action_33,
 action_34,
 action_35,
 action_36,
 action_37,
 action_38,
 action_39,
 action_40,
 action_41,
 action_42,
 action_43,
 action_44,
 action_45,
 action_46,
 action_47,
 action_48,
 action_49,
 action_50,
 action_51,
 action_52,
 action_53,
 action_54,
 action_55,
 action_56,
 action_57,
 action_58,
 action_59,
 action_60,
 action_61,
 action_62,
 action_63,
 action_64,
 action_65,
 action_66,
 action_67,
 action_68,
 action_69,
 action_70,
 action_71,
 action_72,
 action_73,
 action_74,
 action_75,
 action_76,
 action_77,
 action_78,
 action_79,
 action_80,
 action_81,
 action_82,
 action_83,
 action_84,
 action_85,
 action_86,
 action_87,
 action_88,
 action_89 :: () => Int -> ({-HappyReduction (P) = -}
	   Int 
	-> (Token)
	-> HappyState (Token) (HappyStk HappyAbsSyn -> (P) HappyAbsSyn)
	-> [HappyState (Token) (HappyStk HappyAbsSyn -> (P) HappyAbsSyn)] 
	-> HappyStk HappyAbsSyn 
	-> (P) HappyAbsSyn)

happyReduce_1,
 happyReduce_2,
 happyReduce_3,
 happyReduce_4,
 happyReduce_5,
 happyReduce_6,
 happyReduce_7,
 happyReduce_8,
 happyReduce_9,
 happyReduce_10,
 happyReduce_11,
 happyReduce_12,
 happyReduce_13,
 happyReduce_14,
 happyReduce_15,
 happyReduce_16,
 happyReduce_17,
 happyReduce_18,
 happyReduce_19,
 happyReduce_20,
 happyReduce_21,
 happyReduce_22,
 happyReduce_23,
 happyReduce_24,
 happyReduce_25,
 happyReduce_26,
 happyReduce_27,
 happyReduce_28,
 happyReduce_29,
 happyReduce_30,
 happyReduce_31,
 happyReduce_32,
 happyReduce_33,
 happyReduce_34,
 happyReduce_35,
 happyReduce_36,
 happyReduce_37,
 happyReduce_38,
 happyReduce_39,
 happyReduce_40,
 happyReduce_41,
 happyReduce_42,
 happyReduce_43,
 happyReduce_44,
 happyReduce_45,
 happyReduce_46,
 happyReduce_47,
 happyReduce_48,
 happyReduce_49,
 happyReduce_50,
 happyReduce_51,
 happyReduce_52 :: () => ({-HappyReduction (P) = -}
	   Int 
	-> (Token)
	-> HappyState (Token) (HappyStk HappyAbsSyn -> (P) HappyAbsSyn)
	-> [HappyState (Token) (HappyStk HappyAbsSyn -> (P) HappyAbsSyn)] 
	-> HappyStk HappyAbsSyn 
	-> (P) HappyAbsSyn)

action_0 (39) = happyShift action_3
action_0 (4) = happyGoto action_4
action_0 (22) = happyGoto action_2
action_0 _ = happyReduce_52

action_1 (39) = happyShift action_3
action_1 (22) = happyGoto action_2
action_1 _ = happyFail

action_2 (24) = happyShift action_7
action_2 (25) = happyShift action_8
action_2 (26) = happyShift action_9
action_2 (27) = happyShift action_10
action_2 (28) = happyShift action_11
action_2 (29) = happyShift action_12
action_2 (30) = happyShift action_13
action_2 (31) = happyShift action_14
action_2 (32) = happyShift action_15
action_2 (33) = happyShift action_16
action_2 (35) = happyShift action_17
action_2 (36) = happyShift action_18
action_2 (37) = happyShift action_19
action_2 (38) = happyShift action_20
action_2 (16) = happyGoto action_5
action_2 (17) = happyGoto action_6
action_2 _ = happyFail

action_3 _ = happyReduce_51

action_4 (49) = happyAccept
action_4 _ = happyFail

action_5 (24) = happyShift action_7
action_5 (25) = happyShift action_8
action_5 (26) = happyShift action_9
action_5 (27) = happyShift action_10
action_5 (28) = happyShift action_11
action_5 (29) = happyShift action_12
action_5 (30) = happyShift action_13
action_5 (31) = happyShift action_14
action_5 (32) = happyShift action_15
action_5 (33) = happyShift action_16
action_5 (35) = happyShift action_17
action_5 (36) = happyShift action_18
action_5 (37) = happyShift action_19
action_5 (38) = happyShift action_20
action_5 (44) = happyShift action_38
action_5 (17) = happyGoto action_37
action_5 _ = happyFail

action_6 _ = happyReduce_26

action_7 (39) = happyShift action_36
action_7 _ = happyFail

action_8 (23) = happyShift action_35
action_8 (19) = happyGoto action_33
action_8 (20) = happyGoto action_34
action_8 _ = happyFail

action_9 (23) = happyShift action_32
action_9 _ = happyFail

action_10 (23) = happyShift action_31
action_10 _ = happyFail

action_11 (39) = happyShift action_30
action_11 _ = happyFail

action_12 _ = happyReduce_31

action_13 (39) = happyShift action_29
action_13 _ = happyFail

action_14 (23) = happyShift action_26
action_14 (21) = happyGoto action_28
action_14 _ = happyReduce_50

action_15 (23) = happyShift action_26
action_15 (21) = happyGoto action_27
action_15 _ = happyReduce_50

action_16 (23) = happyShift action_26
action_16 (21) = happyGoto action_25
action_16 _ = happyReduce_50

action_17 (40) = happyShift action_24
action_17 _ = happyFail

action_18 (39) = happyShift action_23
action_18 _ = happyFail

action_19 (23) = happyShift action_22
action_19 _ = happyFail

action_20 (39) = happyShift action_21
action_20 _ = happyFail

action_21 _ = happyReduce_42

action_22 (39) = happyShift action_50
action_22 _ = happyFail

action_23 _ = happyReduce_41

action_24 _ = happyReduce_40

action_25 _ = happyReduce_38

action_26 (23) = happyShift action_26
action_26 (21) = happyGoto action_49
action_26 _ = happyReduce_50

action_27 _ = happyReduce_39

action_28 _ = happyReduce_37

action_29 (39) = happyShift action_48
action_29 _ = happyReduce_33

action_30 (39) = happyShift action_47
action_30 _ = happyFail

action_31 (23) = happyShift action_45
action_31 (18) = happyGoto action_46
action_31 _ = happyReduce_45

action_32 (23) = happyShift action_45
action_32 (18) = happyGoto action_44
action_32 _ = happyReduce_45

action_33 _ = happyReduce_28

action_34 (23) = happyShift action_35
action_34 (19) = happyGoto action_43
action_34 (20) = happyGoto action_34
action_34 _ = happyReduce_47

action_35 (39) = happyShift action_42
action_35 _ = happyFail

action_36 _ = happyReduce_27

action_37 _ = happyReduce_25

action_38 (23) = happyShift action_41
action_38 (5) = happyGoto action_39
action_38 (6) = happyGoto action_40
action_38 _ = happyFail

action_39 (23) = happyShift action_41
action_39 (39) = happyShift action_3
action_39 (6) = happyGoto action_54
action_39 (22) = happyGoto action_55
action_39 _ = happyReduce_52

action_40 _ = happyReduce_3

action_41 (46) = happyShift action_53
action_41 (7) = happyGoto action_52
action_41 _ = happyReduce_8

action_42 _ = happyReduce_48

action_43 _ = happyReduce_46

action_44 _ = happyReduce_29

action_45 _ = happyReduce_44

action_46 _ = happyReduce_30

action_47 _ = happyReduce_32

action_48 (39) = happyShift action_51
action_48 _ = happyReduce_34

action_49 _ = happyReduce_49

action_50 _ = happyReduce_43

action_51 (39) = happyShift action_60
action_51 _ = happyReduce_35

action_52 (41) = happyShift action_58
action_52 (43) = happyShift action_59
action_52 _ = happyFail

action_53 (23) = happyShift action_57
action_53 (8) = happyGoto action_56
action_53 _ = happyFail

action_54 _ = happyReduce_2

action_55 _ = happyReduce_1

action_56 (47) = happyShift action_68
action_56 (48) = happyShift action_69
action_56 _ = happyFail

action_57 _ = happyReduce_9

action_58 (23) = happyShift action_67
action_58 (9) = happyGoto action_62
action_58 (10) = happyGoto action_63
action_58 (11) = happyGoto action_64
action_58 (12) = happyGoto action_65
action_58 (13) = happyGoto action_66
action_58 _ = happyReduce_18

action_59 (39) = happyShift action_61
action_59 _ = happyFail

action_60 _ = happyReduce_36

action_61 (23) = happyShift action_76
action_61 (41) = happyShift action_77
action_61 _ = happyFail

action_62 _ = happyReduce_6

action_63 (45) = happyShift action_75
action_63 _ = happyReduce_12

action_64 _ = happyReduce_19

action_65 (34) = happyShift action_74
action_65 (15) = happyGoto action_73
action_65 _ = happyReduce_24

action_66 (23) = happyShift action_67
action_66 (11) = happyGoto action_72
action_66 _ = happyReduce_17

action_67 (46) = happyShift action_71
action_67 _ = happyReduce_15

action_68 _ = happyReduce_7

action_69 (23) = happyShift action_70
action_69 _ = happyFail

action_70 _ = happyReduce_10

action_71 (23) = happyShift action_67
action_71 (11) = happyGoto action_83
action_71 (14) = happyGoto action_84
action_71 _ = happyFail

action_72 _ = happyReduce_20

action_73 (39) = happyShift action_82
action_73 _ = happyFail

action_74 (23) = happyShift action_81
action_74 _ = happyFail

action_75 (23) = happyShift action_67
action_75 (9) = happyGoto action_80
action_75 (10) = happyGoto action_63
action_75 (11) = happyGoto action_64
action_75 (12) = happyGoto action_65
action_75 (13) = happyGoto action_66
action_75 _ = happyReduce_18

action_76 (41) = happyShift action_79
action_76 _ = happyFail

action_77 (23) = happyShift action_67
action_77 (9) = happyGoto action_78
action_77 (10) = happyGoto action_63
action_77 (11) = happyGoto action_64
action_77 (12) = happyGoto action_65
action_77 (13) = happyGoto action_66
action_77 _ = happyReduce_18

action_78 _ = happyReduce_4

action_79 (23) = happyShift action_67
action_79 (9) = happyGoto action_88
action_79 (10) = happyGoto action_63
action_79 (11) = happyGoto action_64
action_79 (12) = happyGoto action_65
action_79 (13) = happyGoto action_66
action_79 _ = happyReduce_18

action_80 _ = happyReduce_11

action_81 _ = happyReduce_23

action_82 (42) = happyShift action_87
action_82 _ = happyReduce_14

action_83 _ = happyReduce_21

action_84 (47) = happyShift action_85
action_84 (48) = happyShift action_86
action_84 _ = happyFail

action_85 _ = happyReduce_16

action_86 (23) = happyShift action_67
action_86 (11) = happyGoto action_89
action_86 _ = happyFail

action_87 _ = happyReduce_13

action_88 _ = happyReduce_5

action_89 _ = happyReduce_22

happyReduce_1 = happyReduce 5 4 happyReduction_1
happyReduction_1 ((HappyAbsSyn15  happy_var_5) `HappyStk`
	(HappyAbsSyn5  happy_var_4) `HappyStk`
	_ `HappyStk`
	(HappyAbsSyn16  happy_var_2) `HappyStk`
	(HappyAbsSyn15  happy_var_1) `HappyStk`
	happyRest)
	 = HappyAbsSyn4
		 (AbsSyn happy_var_1 (reverse happy_var_2) (reverse happy_var_4) happy_var_5
	) `HappyStk` happyRest

happyReduce_2 = happySpecReduce_2  5 happyReduction_2
happyReduction_2 (HappyAbsSyn6  happy_var_2)
	(HappyAbsSyn5  happy_var_1)
	 =  HappyAbsSyn5
		 (happy_var_2 : happy_var_1
	)
happyReduction_2 _ _  = notHappyAtAll 

happyReduce_3 = happySpecReduce_1  5 happyReduction_3
happyReduction_3 (HappyAbsSyn6  happy_var_1)
	 =  HappyAbsSyn5
		 ([happy_var_1]
	)
happyReduction_3 _  = notHappyAtAll 

happyReduce_4 = happyReduce 6 6 happyReduction_4
happyReduction_4 ((HappyAbsSyn9  happy_var_6) `HappyStk`
	_ `HappyStk`
	(HappyTerminal (TokenInfo happy_var_4 TokCodeQuote)) `HappyStk`
	_ `HappyStk`
	(HappyAbsSyn7  happy_var_2) `HappyStk`
	(HappyTerminal (TokenInfo happy_var_1 TokId)) `HappyStk`
	happyRest)
	 = HappyAbsSyn6
		 ((happy_var_1,happy_var_2,happy_var_6,Just happy_var_4)
	) `HappyStk` happyRest

happyReduce_5 = happyReduce 7 6 happyReduction_5
happyReduction_5 ((HappyAbsSyn9  happy_var_7) `HappyStk`
	_ `HappyStk`
	_ `HappyStk`
	(HappyTerminal (TokenInfo happy_var_4 TokCodeQuote)) `HappyStk`
	_ `HappyStk`
	(HappyAbsSyn7  happy_var_2) `HappyStk`
	(HappyTerminal (TokenInfo happy_var_1 TokId)) `HappyStk`
	happyRest)
	 = HappyAbsSyn6
		 ((happy_var_1,happy_var_2,happy_var_7,Just happy_var_4)
	) `HappyStk` happyRest

happyReduce_6 = happyReduce 4 6 happyReduction_6
happyReduction_6 ((HappyAbsSyn9  happy_var_4) `HappyStk`
	_ `HappyStk`
	(HappyAbsSyn7  happy_var_2) `HappyStk`
	(HappyTerminal (TokenInfo happy_var_1 TokId)) `HappyStk`
	happyRest)
	 = HappyAbsSyn6
		 ((happy_var_1,happy_var_2,happy_var_4,Nothing)
	) `HappyStk` happyRest

happyReduce_7 = happySpecReduce_3  7 happyReduction_7
happyReduction_7 _
	(HappyAbsSyn7  happy_var_2)
	_
	 =  HappyAbsSyn7
		 (reverse happy_var_2
	)
happyReduction_7 _ _ _  = notHappyAtAll 

happyReduce_8 = happySpecReduce_0  7 happyReduction_8
happyReduction_8  =  HappyAbsSyn7
		 ([]
	)

happyReduce_9 = happySpecReduce_1  8 happyReduction_9
happyReduction_9 (HappyTerminal (TokenInfo happy_var_1 TokId))
	 =  HappyAbsSyn7
		 ([happy_var_1]
	)
happyReduction_9 _  = notHappyAtAll 

happyReduce_10 = happySpecReduce_3  8 happyReduction_10
happyReduction_10 (HappyTerminal (TokenInfo happy_var_3 TokId))
	_
	(HappyAbsSyn7  happy_var_1)
	 =  HappyAbsSyn7
		 (happy_var_3 : happy_var_1
	)
happyReduction_10 _ _ _  = notHappyAtAll 

happyReduce_11 = happySpecReduce_3  9 happyReduction_11
happyReduction_11 (HappyAbsSyn9  happy_var_3)
	_
	(HappyAbsSyn10  happy_var_1)
	 =  HappyAbsSyn9
		 (happy_var_1 : happy_var_3
	)
happyReduction_11 _ _ _  = notHappyAtAll 

happyReduce_12 = happySpecReduce_1  9 happyReduction_12
happyReduction_12 (HappyAbsSyn10  happy_var_1)
	 =  HappyAbsSyn9
		 ([happy_var_1]
	)
happyReduction_12 _  = notHappyAtAll 

happyReduce_13 = happyMonadReduce 4 10 happyReduction_13
happyReduction_13 (_ `HappyStk`
	(HappyTerminal (TokenInfo happy_var_3 TokCodeQuote)) `HappyStk`
	(HappyAbsSyn15  happy_var_2) `HappyStk`
	(HappyAbsSyn12  happy_var_1) `HappyStk`
	happyRest) tk
	 = happyThen (( lineP >>= \l -> return (happy_var_1,happy_var_3,l,happy_var_2))
	) (\r -> happyReturn (HappyAbsSyn10 r))

happyReduce_14 = happyMonadReduce 3 10 happyReduction_14
happyReduction_14 ((HappyTerminal (TokenInfo happy_var_3 TokCodeQuote)) `HappyStk`
	(HappyAbsSyn15  happy_var_2) `HappyStk`
	(HappyAbsSyn12  happy_var_1) `HappyStk`
	happyRest) tk
	 = happyThen (( lineP >>= \l -> return (happy_var_1,happy_var_3,l,happy_var_2))
	) (\r -> happyReturn (HappyAbsSyn10 r))

happyReduce_15 = happySpecReduce_1  11 happyReduction_15
happyReduction_15 (HappyTerminal (TokenInfo happy_var_1 TokId))
	 =  HappyAbsSyn11
		 (App happy_var_1 []
	)
happyReduction_15 _  = notHappyAtAll 

happyReduce_16 = happyReduce 4 11 happyReduction_16
happyReduction_16 (_ `HappyStk`
	(HappyAbsSyn12  happy_var_3) `HappyStk`
	_ `HappyStk`
	(HappyTerminal (TokenInfo happy_var_1 TokId)) `HappyStk`
	happyRest)
	 = HappyAbsSyn11
		 (App happy_var_1 (reverse happy_var_3)
	) `HappyStk` happyRest

happyReduce_17 = happySpecReduce_1  12 happyReduction_17
happyReduction_17 (HappyAbsSyn12  happy_var_1)
	 =  HappyAbsSyn12
		 (reverse happy_var_1
	)
happyReduction_17 _  = notHappyAtAll 

happyReduce_18 = happySpecReduce_0  12 happyReduction_18
happyReduction_18  =  HappyAbsSyn12
		 ([]
	)

happyReduce_19 = happySpecReduce_1  13 happyReduction_19
happyReduction_19 (HappyAbsSyn11  happy_var_1)
	 =  HappyAbsSyn12
		 ([happy_var_1]
	)
happyReduction_19 _  = notHappyAtAll 

happyReduce_20 = happySpecReduce_2  13 happyReduction_20
happyReduction_20 (HappyAbsSyn11  happy_var_2)
	(HappyAbsSyn12  happy_var_1)
	 =  HappyAbsSyn12
		 (happy_var_2 : happy_var_1
	)
happyReduction_20 _ _  = notHappyAtAll 

happyReduce_21 = happySpecReduce_1  14 happyReduction_21
happyReduction_21 (HappyAbsSyn11  happy_var_1)
	 =  HappyAbsSyn12
		 ([happy_var_1]
	)
happyReduction_21 _  = notHappyAtAll 

happyReduce_22 = happySpecReduce_3  14 happyReduction_22
happyReduction_22 (HappyAbsSyn11  happy_var_3)
	_
	(HappyAbsSyn12  happy_var_1)
	 =  HappyAbsSyn12
		 (happy_var_3 : happy_var_1
	)
happyReduction_22 _ _ _  = notHappyAtAll 

happyReduce_23 = happySpecReduce_2  15 happyReduction_23
happyReduction_23 (HappyTerminal (TokenInfo happy_var_2 TokId))
	_
	 =  HappyAbsSyn15
		 (Just happy_var_2
	)
happyReduction_23 _ _  = notHappyAtAll 

happyReduce_24 = happySpecReduce_0  15 happyReduction_24
happyReduction_24  =  HappyAbsSyn15
		 (Nothing
	)

happyReduce_25 = happySpecReduce_2  16 happyReduction_25
happyReduction_25 (HappyAbsSyn17  happy_var_2)
	(HappyAbsSyn16  happy_var_1)
	 =  HappyAbsSyn16
		 (happy_var_2 : happy_var_1
	)
happyReduction_25 _ _  = notHappyAtAll 

happyReduce_26 = happySpecReduce_1  16 happyReduction_26
happyReduction_26 (HappyAbsSyn17  happy_var_1)
	 =  HappyAbsSyn16
		 ([happy_var_1]
	)
happyReduction_26 _  = notHappyAtAll 

happyReduce_27 = happySpecReduce_2  17 happyReduction_27
happyReduction_27 (HappyTerminal (TokenInfo happy_var_2 TokCodeQuote))
	_
	 =  HappyAbsSyn17
		 (TokenType happy_var_2
	)
happyReduction_27 _ _  = notHappyAtAll 

happyReduce_28 = happySpecReduce_2  17 happyReduction_28
happyReduction_28 (HappyAbsSyn19  happy_var_2)
	_
	 =  HappyAbsSyn17
		 (TokenSpec happy_var_2
	)
happyReduction_28 _ _  = notHappyAtAll 

happyReduce_29 = happySpecReduce_3  17 happyReduction_29
happyReduction_29 (HappyAbsSyn15  happy_var_3)
	(HappyTerminal (TokenInfo happy_var_2 TokId))
	_
	 =  HappyAbsSyn17
		 (TokenName happy_var_2 happy_var_3 False
	)
happyReduction_29 _ _ _  = notHappyAtAll 

happyReduce_30 = happySpecReduce_3  17 happyReduction_30
happyReduction_30 (HappyAbsSyn15  happy_var_3)
	(HappyTerminal (TokenInfo happy_var_2 TokId))
	_
	 =  HappyAbsSyn17
		 (TokenName happy_var_2 happy_var_3 True
	)
happyReduction_30 _ _ _  = notHappyAtAll 

happyReduce_31 = happySpecReduce_1  17 happyReduction_31
happyReduction_31 _
	 =  HappyAbsSyn17
		 (TokenImportedIdentity
	)

happyReduce_32 = happySpecReduce_3  17 happyReduction_32
happyReduction_32 (HappyTerminal (TokenInfo happy_var_3 TokCodeQuote))
	(HappyTerminal (TokenInfo happy_var_2 TokCodeQuote))
	_
	 =  HappyAbsSyn17
		 (TokenLexer happy_var_2 happy_var_3
	)
happyReduction_32 _ _ _  = notHappyAtAll 

happyReduce_33 = happySpecReduce_2  17 happyReduction_33
happyReduction_33 (HappyTerminal (TokenInfo happy_var_2 TokCodeQuote))
	_
	 =  HappyAbsSyn17
		 (TokenMonad "()" happy_var_2 ">>=" "return"
	)
happyReduction_33 _ _  = notHappyAtAll 

happyReduce_34 = happySpecReduce_3  17 happyReduction_34
happyReduction_34 (HappyTerminal (TokenInfo happy_var_3 TokCodeQuote))
	(HappyTerminal (TokenInfo happy_var_2 TokCodeQuote))
	_
	 =  HappyAbsSyn17
		 (TokenMonad happy_var_2 happy_var_3 ">>=" "return"
	)
happyReduction_34 _ _ _  = notHappyAtAll 

happyReduce_35 = happyReduce 4 17 happyReduction_35
happyReduction_35 ((HappyTerminal (TokenInfo happy_var_4 TokCodeQuote)) `HappyStk`
	(HappyTerminal (TokenInfo happy_var_3 TokCodeQuote)) `HappyStk`
	(HappyTerminal (TokenInfo happy_var_2 TokCodeQuote)) `HappyStk`
	_ `HappyStk`
	happyRest)
	 = HappyAbsSyn17
		 (TokenMonad "()" happy_var_2 happy_var_3 happy_var_4
	) `HappyStk` happyRest

happyReduce_36 = happyReduce 5 17 happyReduction_36
happyReduction_36 ((HappyTerminal (TokenInfo happy_var_5 TokCodeQuote)) `HappyStk`
	(HappyTerminal (TokenInfo happy_var_4 TokCodeQuote)) `HappyStk`
	(HappyTerminal (TokenInfo happy_var_3 TokCodeQuote)) `HappyStk`
	(HappyTerminal (TokenInfo happy_var_2 TokCodeQuote)) `HappyStk`
	_ `HappyStk`
	happyRest)
	 = HappyAbsSyn17
		 (TokenMonad happy_var_2 happy_var_3 happy_var_4 happy_var_5
	) `HappyStk` happyRest

happyReduce_37 = happySpecReduce_2  17 happyReduction_37
happyReduction_37 (HappyAbsSyn7  happy_var_2)
	_
	 =  HappyAbsSyn17
		 (TokenNonassoc happy_var_2
	)
happyReduction_37 _ _  = notHappyAtAll 

happyReduce_38 = happySpecReduce_2  17 happyReduction_38
happyReduction_38 (HappyAbsSyn7  happy_var_2)
	_
	 =  HappyAbsSyn17
		 (TokenRight happy_var_2
	)
happyReduction_38 _ _  = notHappyAtAll 

happyReduce_39 = happySpecReduce_2  17 happyReduction_39
happyReduction_39 (HappyAbsSyn7  happy_var_2)
	_
	 =  HappyAbsSyn17
		 (TokenLeft happy_var_2
	)
happyReduction_39 _ _  = notHappyAtAll 

happyReduce_40 = happySpecReduce_2  17 happyReduction_40
happyReduction_40 (HappyTerminal (TokenNum happy_var_2  TokNum))
	_
	 =  HappyAbsSyn17
		 (TokenExpect happy_var_2
	)
happyReduction_40 _ _  = notHappyAtAll 

happyReduce_41 = happySpecReduce_2  17 happyReduction_41
happyReduction_41 (HappyTerminal (TokenInfo happy_var_2 TokCodeQuote))
	_
	 =  HappyAbsSyn17
		 (TokenError happy_var_2
	)
happyReduction_41 _ _  = notHappyAtAll 

happyReduce_42 = happySpecReduce_2  17 happyReduction_42
happyReduction_42 (HappyTerminal (TokenInfo happy_var_2 TokCodeQuote))
	_
	 =  HappyAbsSyn17
		 (TokenAttributetype happy_var_2
	)
happyReduction_42 _ _  = notHappyAtAll 

happyReduce_43 = happySpecReduce_3  17 happyReduction_43
happyReduction_43 (HappyTerminal (TokenInfo happy_var_3 TokCodeQuote))
	(HappyTerminal (TokenInfo happy_var_2 TokId))
	_
	 =  HappyAbsSyn17
		 (TokenAttribute happy_var_2 happy_var_3
	)
happyReduction_43 _ _ _  = notHappyAtAll 

happyReduce_44 = happySpecReduce_1  18 happyReduction_44
happyReduction_44 (HappyTerminal (TokenInfo happy_var_1 TokId))
	 =  HappyAbsSyn15
		 (Just happy_var_1
	)
happyReduction_44 _  = notHappyAtAll 

happyReduce_45 = happySpecReduce_0  18 happyReduction_45
happyReduction_45  =  HappyAbsSyn15
		 (Nothing
	)

happyReduce_46 = happySpecReduce_2  19 happyReduction_46
happyReduction_46 (HappyAbsSyn19  happy_var_2)
	(HappyAbsSyn20  happy_var_1)
	 =  HappyAbsSyn19
		 (happy_var_1:happy_var_2
	)
happyReduction_46 _ _  = notHappyAtAll 

happyReduce_47 = happySpecReduce_1  19 happyReduction_47
happyReduction_47 (HappyAbsSyn20  happy_var_1)
	 =  HappyAbsSyn19
		 ([happy_var_1]
	)
happyReduction_47 _  = notHappyAtAll 

happyReduce_48 = happySpecReduce_2  20 happyReduction_48
happyReduction_48 (HappyTerminal (TokenInfo happy_var_2 TokCodeQuote))
	(HappyTerminal (TokenInfo happy_var_1 TokId))
	 =  HappyAbsSyn20
		 ((happy_var_1,happy_var_2)
	)
happyReduction_48 _ _  = notHappyAtAll 

happyReduce_49 = happySpecReduce_2  21 happyReduction_49
happyReduction_49 (HappyAbsSyn7  happy_var_2)
	(HappyTerminal (TokenInfo happy_var_1 TokId))
	 =  HappyAbsSyn7
		 (happy_var_1 : happy_var_2
	)
happyReduction_49 _ _  = notHappyAtAll 

happyReduce_50 = happySpecReduce_0  21 happyReduction_50
happyReduction_50  =  HappyAbsSyn7
		 ([]
	)

happyReduce_51 = happySpecReduce_1  22 happyReduction_51
happyReduction_51 (HappyTerminal (TokenInfo happy_var_1 TokCodeQuote))
	 =  HappyAbsSyn15
		 (Just happy_var_1
	)
happyReduction_51 _  = notHappyAtAll 

happyReduce_52 = happySpecReduce_0  22 happyReduction_52
happyReduction_52  =  HappyAbsSyn15
		 (Nothing
	)

happyNewToken action sts stk
	= lexer(\tk -> 
	let cont i = action i i tk (HappyState action) sts stk in
	case tk of {
	TokenEOF -> action 49 49 tk (HappyState action) sts stk;
	TokenInfo happy_dollar_dollar TokId -> cont 23;
	TokenKW      TokSpecId_TokenType -> cont 24;
	TokenKW      TokSpecId_Token -> cont 25;
	TokenKW      TokSpecId_Name -> cont 26;
	TokenKW      TokSpecId_Partial -> cont 27;
	TokenKW      TokSpecId_Lexer -> cont 28;
	TokenKW      TokSpecId_ImportedIdentity -> cont 29;
	TokenKW      TokSpecId_Monad -> cont 30;
	TokenKW      TokSpecId_Nonassoc -> cont 31;
	TokenKW      TokSpecId_Left -> cont 32;
	TokenKW      TokSpecId_Right -> cont 33;
	TokenKW      TokSpecId_Prec -> cont 34;
	TokenKW      TokSpecId_Expect -> cont 35;
	TokenKW      TokSpecId_Error -> cont 36;
	TokenKW      TokSpecId_Attribute -> cont 37;
	TokenKW      TokSpecId_Attributetype -> cont 38;
	TokenInfo happy_dollar_dollar TokCodeQuote -> cont 39;
	TokenNum happy_dollar_dollar  TokNum -> cont 40;
	TokenKW      TokColon -> cont 41;
	TokenKW      TokSemiColon -> cont 42;
	TokenKW      TokDoubleColon -> cont 43;
	TokenKW      TokDoublePercent -> cont 44;
	TokenKW      TokBar -> cont 45;
	TokenKW      TokParenL -> cont 46;
	TokenKW      TokParenR -> cont 47;
	TokenKW      TokComma -> cont 48;
	_ -> happyError' tk
	})

happyError_ 49 tk = happyError' tk
happyError_ _ tk = happyError' tk

happyThen :: () => P a -> (a -> P b) -> P b
happyThen = (>>=)
happyReturn :: () => a -> P a
happyReturn = (return)
happyThen1 = happyThen
happyReturn1 :: () => a -> P a
happyReturn1 = happyReturn
happyError' :: () => (Token) -> P a
happyError' tk = (\token -> happyError) tk

ourParser = happySomeParser where
  happySomeParser = happyThen (happyParse action_0) (\x -> case x of {HappyAbsSyn4 z -> happyReturn z; _other -> notHappyAtAll })

happySeq = happyDontSeq


happyError :: P a
happyError = lineP >>= \l -> fail (show l ++ ": Parse error\n")
-- $Id: GenericTemplate.hs,v 1.26 2005/01/14 14:47:22 simonmar Exp $





















































































infixr 9 `HappyStk`
data HappyStk a = HappyStk a (HappyStk a)

-----------------------------------------------------------------------------
-- starting the parse

happyParse start_state = happyNewToken start_state notHappyAtAll notHappyAtAll

-----------------------------------------------------------------------------
-- Accepting the parse

-- If the current token is ERROR_TOK, it means we've just accepted a partial
-- parse (a %partial parser).  We must ignore the saved token on the top of
-- the stack in this case.
happyAccept (1) tk st sts (_ `HappyStk` ans `HappyStk` _) =
        happyReturn1 ans
happyAccept j tk st sts (HappyStk ans _) = 
         (happyReturn1 ans)

-----------------------------------------------------------------------------
-- Arrays only: do the next action
















































-----------------------------------------------------------------------------
-- HappyState data type (not arrays)



newtype HappyState b c = HappyState
        (Int ->                    -- token number
         Int ->                    -- token number (yes, again)
         b ->                           -- token semantic value
         HappyState b c ->              -- current state
         [HappyState b c] ->            -- state stack
         c)



-----------------------------------------------------------------------------
-- Shifting a token

happyShift new_state (1) tk st sts stk@(x `HappyStk` _) =
     let i = (case x of { HappyErrorToken (i) -> i }) in
--     trace "shifting the error token" $
     new_state i i tk (HappyState (new_state)) ((st):(sts)) (stk)

happyShift new_state i tk st sts stk =
     happyNewToken new_state ((st):(sts)) ((HappyTerminal (tk))`HappyStk`stk)

-- happyReduce is specialised for the common cases.

happySpecReduce_0 i fn (1) tk st sts stk
     = happyFail (1) tk st sts stk
happySpecReduce_0 nt fn j tk st@((HappyState (action))) sts stk
     = action nt j tk st ((st):(sts)) (fn `HappyStk` stk)

happySpecReduce_1 i fn (1) tk st sts stk
     = happyFail (1) tk st sts stk
happySpecReduce_1 nt fn j tk _ sts@(((st@(HappyState (action))):(_))) (v1`HappyStk`stk')
     = let r = fn v1 in
       happySeq r (action nt j tk st sts (r `HappyStk` stk'))

happySpecReduce_2 i fn (1) tk st sts stk
     = happyFail (1) tk st sts stk
happySpecReduce_2 nt fn j tk _ ((_):(sts@(((st@(HappyState (action))):(_))))) (v1`HappyStk`v2`HappyStk`stk')
     = let r = fn v1 v2 in
       happySeq r (action nt j tk st sts (r `HappyStk` stk'))

happySpecReduce_3 i fn (1) tk st sts stk
     = happyFail (1) tk st sts stk
happySpecReduce_3 nt fn j tk _ ((_):(((_):(sts@(((st@(HappyState (action))):(_))))))) (v1`HappyStk`v2`HappyStk`v3`HappyStk`stk')
     = let r = fn v1 v2 v3 in
       happySeq r (action nt j tk st sts (r `HappyStk` stk'))

happyReduce k i fn (1) tk st sts stk
     = happyFail (1) tk st sts stk
happyReduce k nt fn j tk st sts stk
     = case happyDrop (k - ((1) :: Int)) sts of
         sts1@(((st1@(HappyState (action))):(_))) ->
                let r = fn stk in  -- it doesn't hurt to always seq here...
                happyDoSeq r (action nt j tk st1 sts1 r)

happyMonadReduce k nt fn (1) tk st sts stk
     = happyFail (1) tk st sts stk
happyMonadReduce k nt fn j tk st sts stk =
      case happyDrop k ((st):(sts)) of
        sts1@(((st1@(HappyState (action))):(_))) ->
          let drop_stk = happyDropStk k stk in
          happyThen1 (fn stk tk) (\r -> action nt j tk st1 sts1 (r `HappyStk` drop_stk))

happyMonad2Reduce k nt fn (1) tk st sts stk
     = happyFail (1) tk st sts stk
happyMonad2Reduce k nt fn j tk st sts stk =
      case happyDrop k ((st):(sts)) of
        sts1@(((st1@(HappyState (action))):(_))) ->
         let drop_stk = happyDropStk k stk





             new_state = action

          in
          happyThen1 (fn stk tk) (\r -> happyNewToken new_state sts1 (r `HappyStk` drop_stk))

happyDrop (0) l = l
happyDrop n ((_):(t)) = happyDrop (n - ((1) :: Int)) t

happyDropStk (0) l = l
happyDropStk n (x `HappyStk` xs) = happyDropStk (n - ((1)::Int)) xs

-----------------------------------------------------------------------------
-- Moving to a new state after a reduction









happyGoto action j tk st = action j j tk (HappyState action)


-----------------------------------------------------------------------------
-- Error recovery (ERROR_TOK is the error token)

-- parse error if we are in recovery and we fail again
happyFail (1) tk old_st _ stk@(x `HappyStk` _) =
     let i = (case x of { HappyErrorToken (i) -> i }) in
--      trace "failing" $ 
        happyError_ i tk

{-  We don't need state discarding for our restricted implementation of
    "error".  In fact, it can cause some bogus parses, so I've disabled it
    for now --SDM

-- discard a state
happyFail  ERROR_TOK tk old_st CONS(HAPPYSTATE(action),sts) 
                                                (saved_tok `HappyStk` _ `HappyStk` stk) =
--      trace ("discarding state, depth " ++ show (length stk))  $
        DO_ACTION(action,ERROR_TOK,tk,sts,(saved_tok`HappyStk`stk))
-}

-- Enter error recovery: generate an error token,
--                       save the old token and carry on.
happyFail  i tk (HappyState (action)) sts stk =
--      trace "entering error recovery" $
        action (1) (1) tk (HappyState (action)) sts ((HappyErrorToken (i)) `HappyStk` stk)

-- Internal happy errors:

notHappyAtAll :: a
notHappyAtAll = error "Internal Happy error\n"

-----------------------------------------------------------------------------
-- Hack to get the typechecker to accept our action functions







-----------------------------------------------------------------------------
-- Seq-ing.  If the --strict flag is given, then Happy emits 
--      happySeq = happyDoSeq
-- otherwise it emits
--      happySeq = happyDontSeq

happyDoSeq, happyDontSeq :: a -> b -> b
happyDoSeq   a b = a `seq` b
happyDontSeq a b = b

-----------------------------------------------------------------------------
-- Don't inline any functions from the template.  GHC has a nasty habit
-- of deciding to inline happyGoto everywhere, which increases the size of
-- the generated parser quite a bit.









{-# NOINLINE happyShift #-}
{-# NOINLINE happySpecReduce_0 #-}
{-# NOINLINE happySpecReduce_1 #-}
{-# NOINLINE happySpecReduce_2 #-}
{-# NOINLINE happySpecReduce_3 #-}
{-# NOINLINE happyReduce #-}
{-# NOINLINE happyMonadReduce #-}
{-# NOINLINE happyGoto #-}
{-# NOINLINE happyFail #-}

-- end of Happy Template.
