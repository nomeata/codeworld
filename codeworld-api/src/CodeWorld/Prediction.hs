{-
  Copyright 2016 The CodeWorld Authors. All rights reserved.

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

{- |
This module encapsulates the logics behind the prediction code in the
multi-player setup.
-}

{-# LANGUAGE RecordWildCards, ViewPatterns #-}
module CodeWorld.Prediction
    ( Timestamp, AnimationRate, StepFun
    , Future
    , initFuture, currentTimePasses, currentState
    , addEvent
    )
    where

import Data.Foldable (toList)
import qualified Data.IntMap as IM
import qualified Data.Map as M
import Data.Bifunctor (second)
import Data.List (foldl')

type PlayerId = Int
type Timestamp = Double     -- in seconds, relative to some arbitrary starting point
type AnimationRate = Double -- in seconds, e.g. 0.1

-- All we do with events is to apply them to the state. So let's just store the
-- function that does that.
type Event s = s -> s

-- A state and an event only make sense together with a time.
type TState s = (Timestamp, s)
type TEvent s = (Timestamp, Event s)

type StepFun s = Double -> s -> s
type PendingEvents s = M.Map Timestamp (Event s)


data Future s = Future
        { committed  :: TState s
        , lastEvents :: IM.IntMap Timestamp
        , pending    :: PendingEvents s
        , current    :: TState s
        }

initFuture :: s -> Int -> Future s
initFuture s numPlayers = Future
    { committed   = (0, s)
    , lastEvents  = IM.fromList [ (n,0) | n <-[0..numPlayers-1]]
    , pending     = M.empty
    , current     = (0, s)
    }

-- Time handling.
--
-- Move state forward in fixed animation rate steps, and get
-- the timestamp as close to the given target as possible (but possibly stop short)
timePassesBigStep :: StepFun s -> AnimationRate -> Timestamp -> TState s -> TState s
timePassesBigStep step rate target (now, s)
    | now + rate < target
    = timePasses step rate target (stepBy step rate (now, s))
    | otherwise
    = (now, s)

-- Move state forward in fixed animation rate steps, and get
-- the timestamp as close to the given target as possible, and then do a final small step
timePasses :: StepFun s -> AnimationRate -> Timestamp -> TState s -> TState s
timePasses step rate target
    = stepTo step target . timePassesBigStep step rate target

stepBy :: StepFun s -> Double -> TState s -> TState s
stepBy step diff (now,s) = (now + diff, step diff s)

stepTo :: StepFun s -> Timestamp -> TState s -> TState s
stepTo step target (now, s)
    = (target, step (target - now) s)

handleNextEvent :: StepFun s -> AnimationRate -> TEvent s -> TState s -> TState s
handleNextEvent step rate (target, event)
    = second event . timePasses step rate target

handleNextEvents :: StepFun s -> AnimationRate -> [TEvent s] -> TState s -> TState s
handleNextEvents step rate tevs ts
  = foldl' (flip (handleNextEvent step rate)) ts tevs

currentState :: StepFun s -> AnimationRate -> Timestamp -> Future s -> s
currentState step rate target f = snd $ timePasses step rate target (current f)

currentTimePasses :: StepFun s -> AnimationRate -> Timestamp -> Future s -> Future s
currentTimePasses step rate target f
 = f { current = timePassesBigStep step rate target $ current f }

addEvent :: StepFun s -> AnimationRate ->
    PlayerId -> Timestamp -> Event s ->
    Future s -> Future s
addEvent step rate player now event f
  = advancePending step rate $
    advanceCommitted step rate $
    f { lastEvents = IM.insert player now $ lastEvents f
      , pending    = M.insert now event $ pending f
      }

advanceCommitted :: StepFun s -> AnimationRate -> Future s -> Future s
advanceCommitted step rate f
    | null eventsToCommit = f -- do not bother
    | otherwise = f { committed = committed', pending = pending' }
  where
    commitTime' = minimum $ IM.elems $ lastEvents f
    canCommit (t,_e) = t <= commitTime'
    (eventsToCommit, uncommitedEvents) = span canCommit $ M.toList (pending f)

    pending' = M.fromAscList uncommitedEvents
    committed' = handleNextEvents step rate eventsToCommit $ committed f

advancePending :: StepFun s -> AnimationRate -> Future s -> Future s
advancePending step rate f
    = f { current = handleNextEvents step rate (M.toList (pending f)) $ committed f }
