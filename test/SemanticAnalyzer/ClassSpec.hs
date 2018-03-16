{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE OverloadedLists #-}

module SemanticAnalyzer.ClassSpec
  ( main
  , spec
  ) where

import Control.Monad.Writer (runWriter)
import qualified Data.Map as M
import Data.Map ()
import qualified Parser.AST as AST
import Parser.AST (Formal)
import Parser.ParserUtil (parseFeature, parseProgram)
import qualified Parser.TerminalNode as T
import SemanticAnalyzer.Class
       (AttributeRecord(..), ClassRecord(..), InheritanceErrors(..),
        MethodMap(..), MethodRecord(..), createEnvironment,
        extractAttributeRecord, extractMethodRecord, mergeAttributes,
        mergeMethods)
import Test.Hspec
       (Expectation, Spec, describe, hspec, it, shouldBe)
import Util

main :: IO ()
main = hspec spec

fooFeatures :: T.Identifier -> ClassRecord -> ClassRecord
fooFeatures name parent' = ClassRecord name parent' fooMethods ["x" =: AttributeRecord "x" "X"]

fooMethods :: MethodMap
fooMethods = ["twice" =: MethodRecord "twice" [AST.Formal "num" "Int"] "Int"]

fooClassRecord :: ClassRecord
fooClassRecord = fooFeatures "Foo" ObjectClass

spec :: Spec
spec =
  describe "class" $ do
    describe "method" $ do
      it "should not parse an attribute" $ "foo : Bar" `testMethodRecord` Nothing
      it "should parse a method with no parameters" $
        "foo () : Bar {true}" `testMethodRecord` (Just $ MethodRecord "foo" [] "Bar")
      it "should parse a method with parameters" $
        "foo (x : X, y: Y) : Foo {true}" `testMethodRecord`
        (Just $ MethodRecord "foo" [AST.Formal "x" "X", AST.Formal "y" "Y"] "Foo")
    describe "attribute" $ do
      it "should not parse a method" $ "foo() : Bar {true}" `testAttributeRecord` Nothing
      it "should parse an attribute" $ "foo : Bar" `testAttributeRecord` (Just $ AttributeRecord "foo" "Bar")
    describe "createClassEnvironment" $ do
      it "should be able to parse a program with a class" $
        createEnvironment M.empty (AST.Program []) `shouldBe` M.empty
      it "should be able to parse a program with an orphaned class" $
        createEnvironment [("Foo", "Object")] (parseProgram "class Foo {x : X; twice(num: Int): Int {2 * x};};") `shouldBe`
        ["Foo" =: fooClassRecord]
      it "should be able to retrieve attributes from it's parent class" $
        createEnvironment
          [("Bar", "Foo"), ("Foo", "Object")]
          (parseProgram "class Foo {x : X; twice(num: Int): Int {2 * x};}; class Bar inherits Bar {};") `shouldBe`
        ["Bar" =: fooFeatures "Bar" fooClassRecord, "Foo" =: fooClassRecord]
      it "should be able to extends attributes from it's parent class" $
        createEnvironment
          [("Bar", "Foo"), ("Foo", "Object")]
          (parseProgram "class Foo {x : X; twice(num: Int): Int {2 * x};}; class Bar inherits Foo {y : Y;};") `shouldBe`
        [ "Bar" =:
          ClassRecord "Bar" fooClassRecord fooMethods ["x" =: AttributeRecord "x" "X", "y" =: AttributeRecord "y" "Y"]
        , "Foo" =: fooClassRecord
        ]
    describe "mergeAttributes" $ do
      it "should not produce errors if a class does not inherit attributes that it's parent has" $
        testAttribute
          "Foo"
          ["x" =: AttributeRecord "x" "X"]
          ["y" =: AttributeRecord "y" "Y"]
          (["x" =: AttributeRecord "x" "X", "y" =: AttributeRecord "y" "Y"], [])
      it "should produce errors if a class has attributes that it's parent has" $
        testAttribute
          "Foo"
          ["x" =: AttributeRecord "x" "X", "y" =: AttributeRecord "y" "X"]
          ["y" =: AttributeRecord "y" "Y"]
          (["x" =: AttributeRecord "x" "X", "y" =: AttributeRecord "y" "X"], [RedefinedAttribute "y" "Foo"])
    describe "mergeMethods" $ do
      it "should not report errors for methods if a class does not inherit methods that it's parent has" $
        testMethod
          ["foo" =: MethodRecord "foo" [AST.Formal "x" "X", AST.Formal "y" "Y"] "Z"]
          []
          (["foo" =: MethodRecord "foo" [AST.Formal "x" "X", AST.Formal "y" "Y"] "Z"], [])
      it "should report errrors for methods if a class does inherit a method with no matching return types" $ -- todo test for inheritance
        testMethod
          ["foo" =: MethodRecord "foo" [AST.Formal "x" "X"] "Z"]
          ["foo" =: MethodRecord "foo" [AST.Formal "x" "X"] "Bar"]
          (["foo" =: MethodRecord "foo" [AST.Formal "x" "X"] "Z"], [DifferentMethodReturnType "Z" "Bar"])
  where
    testAttribute className' classAttr parentAttr expectedResult =
      runWriter (mergeAttributes className' classAttr parentAttr) `shouldBe` expectedResult
    testMethod classMethods parentMethods expectedResult =
      runWriter (mergeMethods classMethods parentMethods) `shouldBe` expectedResult

testMethodRecord :: String -> Maybe MethodRecord -> Expectation
testMethodRecord code expected = extractMethodRecord (parseFeature code) `shouldBe` expected

testAttributeRecord :: String -> Maybe AttributeRecord -> Expectation
testAttributeRecord code expected = extractAttributeRecord (parseFeature code) `shouldBe` expected