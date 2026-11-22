module Agent
( predictQ,
bestAction,
maxQValue,
chooseAction,
updateWeights
) where

import Data.List(foldl1')
import System.Random (StdGen, randomR)
import Types
import Features

predictQ :: WeightVector -> State -> Action -> Double
predictQ weights state action =
    --Não esquecer que phi são os pesos
    let !phi = extractFeatures state action
    in dotProduct weights phi

bestAction :: WeightVector -> State -> (Action, Double)
bestAction weights state =
    let scoredActions = [ (a, predictQ weights state a) | a <- allActions ]
        pickMax (!bestA, !bestQ) (!a,!q)
            | q > bestQ = (a,q)
            |otherwise = (bestA,bestQ)
    in foldl1' pickMax scoredActions

maxQValue :: WeightVector -> State -> Double
maxQValue weights state = snd (bestAction weights state)

chooseAction :: WeightVector -> Double -> State -> StdGen -> (Action, StdGen)
chooseAction weights epsilon state gen0 =
    let (!p, !gen1) = randomR (0.0,1.0) gen0
    in if p < epsilon
        then let (!idx, !gen2) = randomR (0,length allActions - 1) gen1
            in (allActions !! idx, gen2)
        else (fst (bestAction weights state), gen1)

updateWeights :: 
    HyperParams
    -> WeightVector
    -> State
    -> Action
    -> Double
    -> State
    -> Bool
    -> WeightVector
updateWeights hp weights state action reward nextState isTerminal =
    let !alpha = hpAlpha hp
        !gamma = hpGamma hp
        !phi = extractFeatures state action
        !currentQ = dotProduct weights phi
        !nextMaxQ = if isTerminal then 0.0 else maxQValue weights nextState
        !target = reward + gamma * nextMaxQ
        !tdError = target - currentQ
        !stepVec = vecScale (alpha * tdError) phi
    in vecAdd weights stepVec