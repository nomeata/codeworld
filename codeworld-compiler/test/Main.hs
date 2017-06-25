{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports    #-}

{-
  Copyright 2017 The CodeWorld Authors. All rights reserved.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
-}


import qualified "codeworld-compiler" Compile as C
import           Data.Char
import           Control.Monad
import           System.Directory
import           Test.HUnit             -- only import needed, others are optional

testcaseDir :: FilePath
testcaseDir = "codeworld-compiler/test/testcase"

test1 = TestCase $ assertEqual "test upCase" "FOO" (map toUpper "foo")

