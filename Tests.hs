{-# OPTIONS_GHC -Wall #-}

import Data.Maybe

import Test.Hspec

import ParseCommon

import Lambda
import ParseLambda

import Debrujin
import ReduceDebrujin
import ParseDebrujin

import LambdaToDebrujin

fromRightUnsafe :: Either a b -> b
fromRightUnsafe (Right b) = b
fromRightUnsafe (Left _) = error "fromRightUnsafe blew up"

parseLambdaUnsafe :: String -> Lambda
parseLambdaUnsafe = fromRightUnsafe . (parseFromStr parseLambda)

parseLambdaTest :: String -> Lambda -> SpecWith ()
parseLambdaTest str expect =
   it ("parseLambdaTest " ++ str) $ do
    (parseLambdaUnsafe str) `shouldBe` expect

parseDebrujinUnsafe :: String -> Debrujin
parseDebrujinUnsafe = fromRightUnsafe . (parseFromStr parseDebrujin)

anonStr :: String -> Debrujin
anonStr = fromJust . lambdaBoundVarsAnonymized . parseLambdaUnsafe

anonStrTest :: String -> Debrujin -> SpecWith ()
anonStrTest str expect =
   it ("anonStrTest " ++ str) $ do
    (anonStr str) `shouldBe` expect

reduceStrOnce :: String -> Debrujin
reduceStrOnce = lambdaBetaReducedOneStep . anonStr

reduceStrOnceTest :: String -> Debrujin -> SpecWith ()
reduceStrOnceTest str expect =
   it ("reduceStrOnceTest " ++ str) $ do
    (reduceStrOnce str) `shouldBe` expect

reduceOnceTest :: Debrujin -> Debrujin -> SpecWith ()
reduceOnceTest start expect =
   it ("reduceOnceTest " ++ show start) $ do
    (lambdaBetaReducedOneStep start) `shouldBe` expect

plusOperator :: Debrujin
plusOperator = (DAB (DAB (DAB (DAB (DAP (DAP (DAR 4) (DAR 2)) (DAP (DAP (DAR 3) (DAR 2)) (DAR 1)))))))

addExpr :: Int -> Int -> Debrujin
addExpr a b = DAP (DAP plusOperator (churchNum a)) (churchNum b)

addExprTest :: Int -> Int -> SpecWith ()
addExprTest a b =
  it ("addExprTest " ++ show a ++ " " ++ show b)$ do 
    (lambdaBetaReducedFull (addExpr a b)) `shouldBe` (churchNum (a + b))

churchNum :: Int -> Debrujin
churchNum n = (DAB (DAB (churchNumHelper n)))

churchNumHelper :: Int -> Debrujin
churchNumHelper 0 = (DAR 1)
churchNumHelper n = (DAP (DAR 2) (churchNumHelper (n-1)))

multOperator :: Debrujin
multOperator = (anonStr "(/ m (/ n (/ g (m (n g)))))")

multExpr :: Int -> Int -> Debrujin
multExpr a b = DAP (DAP multOperator (churchNum a)) (churchNum b)

multExprTest :: Int -> Int -> SpecWith ()
multExprTest a b =
  it ("multExprTest " ++ show a ++ " " ++ show b) $ do 
    (lambdaBetaReducedFull (multExpr a b)) `shouldBe` (churchNum (a * b))

main :: IO ()
main = hspec $ do
  describe "lambda" $ do
    parseLambdaTest "(/ x x)" (LAB "x" (LAR "x"))
    parseLambdaTest "(/ x y)" (LAB "x" (LAR "y"))
    parseLambdaTest "(/ y (/ x (x y)))" (LAB "y" (LAB "x" (LAP (LAR "x") (LAR "y"))))
    parseLambdaTest "((/ x x)(/ x x))" (LAP (LAB "x" (LAR "x")) (LAB "x" (LAR "x")))
   
    anonStrTest "(/ x x)" (DAB (DAR 1))
    anonStrTest "(/ y (/ x (x y)))" (DAB (DAB (DAP (DAR 1) (DAR 2))))
    anonStrTest "(/ y (/ x x))" (DAB (DAB (DAR 1)))
    anonStrTest "((/ x x)(/ x x))" (DAP (DAB (DAR 1)) (DAB (DAR 1)))
    anonStrTest "((/ x (/ y x))(/ x x))" (DAP (DAB (DAB (DAR 2))) (DAB (DAR 1)))
    anonStrTest "(/ m (/ n (/ f (/ x ((m f) ((n f) x))))))" plusOperator
    anonStrTest "(/ f (/ x x))" (churchNum 0)
    anonStrTest "(/ f (/ x (f x)))" (churchNum 1)
    anonStrTest "(/ f (/ x (f (f x))))" (churchNum 2)
    anonStrTest "(/ f (/ x (f (f (f x)))))" (churchNum 3)
    
    reduceStrOnceTest "((/ x x)(/ x x))" (anonStr "(/ x x)")
    reduceStrOnceTest "((/ x (/ y x))(/ x x))" (anonStr "(/ y (/ x x))")
    reduceStrOnceTest "((/ x (/ y (/ z (/ w x)))) (/ a (/ b (/ c (/ d a)))))" (anonStr "(/ y (/ z (/ w (/ a (/ b (/ c (/ d a)))))))")

    addExprTest 0 0
    addExprTest 0 1
    addExprTest 1 0
    addExprTest 1 1
    addExprTest 1 2
    addExprTest 2 1
    addExprTest 3 2
    addExprTest 2 3

    multExprTest 0 0
    multExprTest 0 1
    multExprTest 1 0

    it "multDebug" $ do 
      (shouldBe
          (lambdaIncrementedArgRefsGreaterThan (DAR 1) 1 2)
        )
      --(shouldBe
      --    (lambdaBetaReducedOneStep (parseDebrujinUnsafe "((/ (/ (2 1))) 1)"))
      --    (parseDebrujinUnsafe "(/ (2 1))")
      --  )
      --(shouldBe
      --    (lambdaBetaReducedOneStep (parseDebrujinUnsafe "(/ (/ (((/ (/ (2 1))) 1) 1)))")) 
      --    (parseDebrujinUnsafe "(/ (/ ((/ (2 1)) 1)))")
      --  )
      --(shouldBe
      --    (lambdaBetaReducedOneStep (parseDebrujinUnsafe "(/ ((/ (/ (2 1))) ((/ (/ (2 1))) 1)))"))
      --    (parseDebrujinUnsafe "(/ (/ (2 ((/ (/ (2 1))) 2))))")
      --  )
      --(shouldBe
      --    (reduceStrOnce "(/ g ((/ f (/ x (f x))) ((/ f (/ x (f x))) g)))")
      --    (anonStr "(/ g (/ x (((/ fa (/ xa (fa xa))) g) x)))")
      --  )
      --(lambdaBetaReducedFull (anonStr "(((/ m (/ n (/ g (m (n g))))) (/ f (/ x (f x)))) (/ f (/ x (f x))))")) `shouldBe` (anonStr "(/ f (/ x (f x)))")
      --(lambdaBetaReducedFull (multExpr 1 1)) `shouldBe` (churchNum 1)

    --multExprTest 1 1
    --multExprTest 1 2
    --multExprTest 2 1
    --multExprTest 3 2
    --multExprTest 2 3