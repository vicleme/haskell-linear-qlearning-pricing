{-# LANGUAGE BangPatterns #-}

module Features
  ( featuresPerAction
  , totalFeatures
  , featureNames
  , initWeights
  , extractFeatures
  , dotProduct
  , vecAdd
  , vecScale
  ) where

import Data.List (foldl')
import Types

-- | Número de características base extraídas do estado contínuo s:
-- 0: Bias (1.0)
-- 1: Estoque restante normalizado (sRatio)
-- 2: Tempo restante normalizado (tRatio)
-- 3: Índice de demanda atual (demand)
-- 4: Termo de interação não linear: Escassez × Urgência = (1 - sRatio) * (1 - tRatio)
featuresPerAction :: Int
featuresPerAction = 5

-- | Dimensão total do vetor de características φ(s, a) e de pesos w:
-- 3 ações × 5 features = 15 dimensões (codificação por blocos disjuntos de ação).
totalFeatures :: Int
totalFeatures = length allActions * featuresPerAction

-- | Nomes descritivos das características base para exibição interpretável dos pesos.
featureNames :: [String]
featureNames =
  [ "Bias (Intercepto Base)"
  , "Estoque Restante (sRatio)"
  , "Tempo Restante (tRatio)"
  , "Demanda Observada (Demand)"
  , "Escassez x Urgencia ((1-s)*(1-t))"
  ]

-- | Inicializa o vetor de pesos com zeros (ou valores neutros) de tamanho `totalFeatures`.
initWeights :: WeightVector
initWeights = replicate totalFeatures 0.0

-- | Extrai as 5 características base do estado contínuo s.
baseStateFeatures :: State -> [Double]
baseStateFeatures st =
  let !s = stSeatsRatio st
      !t = stTimeRatio st
      !d = stDemandIndex st
      !scarcityUrgency = (1.0 - s) * (1.0 - t)
  in [1.0, s, t, d, scarcityUrgency]

-- | Constrói o vetor φ(s, a) ∈ ℝ^15 usando codificação por ação (action-block encoding).
-- Apenas o bloco correspondente à ação `a` recebe os atributos de `s`; os demais recebem 0.0.
-- Isso permite que o modelo linear aprenda inclinações distintas para cada política tarifária.
extractFeatures :: State -> Action -> FeatureVector
extractFeatures st action =
  let !baseFeats = baseStateFeatures st
      !zeros     = replicate featuresPerAction 0.0
      !targetIdx = actionIndex action
  in concat [ if idx == targetIdx then baseFeats else zeros
            | idx <- [0 .. length allActions - 1]
            ]

-- | Produto interno estrito: w^T φ(s, a) = Σ (w_i * φ_i).
dotProduct :: WeightVector -> FeatureVector -> Double
dotProduct ws fs = foldl' (\ !acc (!w, !f) -> acc + w * f) 0.0 (zip ws fs)

-- | Soma vetorial estrita: v1 + v2.
vecAdd :: [Double] -> [Double] -> [Double]
vecAdd = zipWith (\ !x !y -> x + y)

-- | Multiplicação de vetor por escalar estrita: c * v.
vecScale :: Double -> [Double] -> [Double]
vecScale !c = map (\ !x -> c * x)
