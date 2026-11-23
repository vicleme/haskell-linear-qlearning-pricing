{-# LANGUAGE BangPatterns #-}

module Metrics
  ( averageReward
  , averageSeatsSold
  , summarizeBlocks
  , exportLearningCurveCSV
  , formatWeightsReport
  ) where

import Data.List (foldl')
import Text.Printf (printf)
import Types
import Features (featuresPerAction, featureNames)

-- | Calcula a receita média de uma lista de episódios em passagem única e estrita.
averageReward :: [EpisodeStats] -> Double
averageReward [] = 0.0
averageReward xs =
  let (!total, !count) = foldl' (\ (!s, !c) ep -> (s + epTotalReward ep, c + (1 :: Int))) (0.0, 0) xs
  in total / fromIntegral count

-- | Calcula a ocupação média (assentos vendidos) de uma lista de episódios.
averageSeatsSold :: [EpisodeStats] -> Double
averageSeatsSold [] = 0.0
averageSeatsSold xs =
  let (!total, !count) = foldl' (\ (!s, !c) ep -> (s + fromIntegral (epSeatsSold ep), c + (1 :: Int))) (0.0, 0) xs
  in total / fromIntegral count

-- | Agrupa os episódios em blocos de tamanho `blockSize` usando pattern matching total (sem head/last).
summarizeBlocks :: Int -> [EpisodeStats] -> [(Int, Int, Double, Double, Double)]
summarizeBlocks _ [] = []
summarizeBlocks blockSize stats = go stats
  where
    go [] = []
    go xs =
      case splitAt blockSize xs of
        ([], _) -> []
        (chunk@(firstEp : _), rest) ->
          let !lastEp   = foldl' (\_ x -> x) firstEp chunk
              !startEp  = epNumber firstEp
              !endEp    = epNumber lastEp
              !avgRev   = averageReward chunk
              !avgSeats = averageSeatsSold chunk
              !endEps   = epEpsilon lastEp
          in (startEp, endEp, avgRev, avgSeats, endEps) : go rest

-- | Exporta o histórico completo de treinamento para um arquivo CSV padronizado.
exportLearningCurveCSV :: FilePath -> [EpisodeStats] -> IO ()
exportLearningCurveCSV path stats = do
  let header = "episodio,receita_total,assentos_vendidos,epsilon\n"
      rows   = map formatRow stats
  writeFile path (header ++ concat rows)
  where
    formatRow ep =
      printf "%d,%.2f,%d,%.4f\n"
        (epNumber ep)
        (epTotalReward ep)
        (epSeatsSold ep)
        (epEpsilon ep)

-- | Formata os pesos finais w aprendidos separados por ação para interpretação econômica.
formatWeightsReport :: WeightVector -> String
formatWeightsReport weights =
  unlines $ concatMap formatActionBlock allActions
  where
    formatActionBlock action =
      let idx      = actionIndex action
          offset   = idx * featuresPerAction
          subW     = take featuresPerAction (drop offset weights)
          header   = printf "\n  Acao: %-18s (Tarifa: R$ %.2f)" (show action) (actionPrice action)
          divider  = "  " ++ replicate 56 '-'
          linesW   = zipWith (\fname wVal -> printf "    %-36s : %+10.3f" fname wVal) featureNames subW
      in header : divider : linesW
