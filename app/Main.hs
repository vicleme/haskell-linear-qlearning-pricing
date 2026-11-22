{-# LANGUAGE BangPatterns #-}

module Main (main) where

import System.Random (StdGen, mkStdGen)
import Text.Printf (printf)
import Types
import Environment
import Features
import Agent
import Metrics

-- | Executa um único episódio completo (do dia 30 até a decolagem ou esgotamento de assentos).
runSingleEpisode
  :: HyperParams
  -> EnvConfig
  -> WeightVector
  -> Double -- ^ Epsilon atual
  -> StdGen
  -> (WeightVector, Double, Int, StdGen)
runSingleEpisode hp cfg initW epsilon gen0 =
  loop (initFlight cfg) initW 0.0 gen0
  where
    loop !env !w !accReward !g
      | envDaysLeft env <= 0 || envSeatsLeft env <= 0 =
          let !sold = cfgTotalSeats cfg - envSeatsLeft env
          in (w, accReward, sold, g)
      | otherwise =
          let !state                     = toState env
              (!action, !g1)             = chooseAction w epsilon state g
              (!nextEnv, !r, !done, !g2) = stepEnv env action g1
              !nextState                 = toState nextEnv
              !updatedW                  = updateWeights hp w state action r nextState done
          in loop nextEnv updatedW (accReward + r) g2

-- | Treina o agente ao longo de N episódios, acumulando métricas com avaliação estrita.
trainAgent
  :: HyperParams
  -> EnvConfig
  -> StdGen
  -> (WeightVector, [EpisodeStats])
trainAgent hp cfg gen0 =
  go 1 (hpEpsilonInit hp) initWeights [] gen0
  where
    !maxEp = hpNumEpisodes hp

    go !ep !eps !w !accStats !g
      | ep > maxEp = (w, reverse accStats)
      | otherwise  =
          let (!w', !totRev, !sold, !g') = runSingleEpisode hp cfg w eps g
              !stat = EpisodeStats
                { epNumber      = ep
                , epTotalReward = totRev
                , epSeatsSold   = sold
                , epEpsilon     = eps
                }
              !nextEps = max (hpEpsilonMin hp) (eps * hpEpsilonDec hp)
          in go (ep + 1) nextEps w' (stat : accStats) g'

-- | Avalia uma política fixa (ex: 100% aleatória ou política aprendida com ε = 0) sem atualizar pesos.
evaluatePolicy
  :: EnvConfig
  -> WeightVector
  -> Double -- ^ Epsilon (1.0 = aleatória, 0.0 = gulosa/aprendida)
  -> Int    -- ^ Número de voos de teste
  -> StdGen
  -> (Double, Double) -- ^ (Receita Média, Ocupação Média)
evaluatePolicy cfg w epsilon numTests gen0 =
  let dummyHp = HyperParams 0.0 1.0 epsilon epsilon 1.0 numTests
      go 0 !accR !accS _ =
        (accR / fromIntegral numTests, fromIntegral accS / fromIntegral numTests)
      go !n !accR !accS !g =
        let (_, !r, !s, !g') = runSingleEpisode dummyHp cfg w epsilon g
        in go (n - 1) (accR + r) (accS + s) g'
  in go numTests 0.0 0 gen0

-- | Avalia uma regra de preco fixa (funcao pura FlightEnv -> Action) em `numTests` voos, sem aprendizado.
evaluateRule
  :: EnvConfig
  -> (FlightEnv -> Action)
  -> Int
  -> StdGen
  -> (Double, Double) -- ^ (Receita Media, Ocupacao Media)
evaluateRule cfg rule numTests gen0 = go numTests 0.0 0 gen0
  where
    go :: Int -> Double -> Int -> StdGen -> (Double, Double)
    go 0 !accR !accS _ =
      (accR / fromIntegral numTests, fromIntegral accS / fromIntegral numTests)
    go !n !accR !accS !g =
      let (!r, !s, !g') = playFlight (initFlight cfg) 0.0 g
      in go (n - 1) (accR + r) (accS + s) g'

    playFlight :: FlightEnv -> Double -> StdGen -> (Double, Int, StdGen)
    playFlight !env !acc !g
      | envDaysLeft env <= 0 || envSeatsLeft env <= 0 =
          (acc, cfgTotalSeats cfg - envSeatsLeft env, g)
      | otherwise =
          let (!nextEnv, !r, _, !g') = stepEnv env (rule env) g
          in playFlight nextEnv (acc + r) g'

main :: IO ()
main = do
  let envCfg = EnvConfig
        { cfgTotalSeats = 100
        , cfgTotalDays  = 30
        }
      hyperParams = HyperParams
        { hpAlpha       = 0.005 -- Taxa de aprendizado calibrada para escala de recompensas (R$)
        , hpGamma       = 0.99   -- Alta valorização da receita futura até a decolagem
        , hpEpsilonInit = 1.00   -- Começa 100% exploratório
        , hpEpsilonMin  = 0.05   -- Mantém 5% de exploração residual
        , hpEpsilonDec  = 0.9985 -- Decaimento suave ao longo de 3.000 episódios
        , hpNumEpisodes = 3000
        }
      seed = 42
      gen  = mkStdGen seed

  putStrLn "======================================================================"
  putStrLn "  LINEAR Q-LEARNING EM HASKELL: PRECIFICACAO DINAMICA DE PASSAGENS"
  putStrLn "======================================================================"
  printf "Configuracao do Voo : %d assentos | Horizonte de %d dias\n"
    (cfgTotalSeats envCfg) (cfgTotalDays envCfg)
  printf "Hiperparametros     : alpha=%.4f | gamma=%.2f | episodios=%d\n\n"
    (hpAlpha hyperParams) (hpGamma hyperParams) (hpNumEpisodes hyperParams)

  -- Treinamento do agente
  let (!finalWeights, !history) = trainAgent hyperParams envCfg gen
      !blocks = summarizeBlocks 500 history

  putStrLn "1. EVOLUCAO DO TREINAMENTO (MEDIAS POR BLOCO DE 500 EPISODIOS)"
  putStrLn "----------------------------------------------------------------------"
  putStrLn "  Episodios      | Receita Media (R$) | Assentos Vendidos | Epsilon"
  putStrLn "----------------------------------------------------------------------"
  mapM_ (\(s, e, rev, seats, eps) ->
    printf "  %4d a %4d    |    R$ %10.2f   |     %6.1f / 100  |  %.4f\n"
      s e rev seats eps
    ) blocks

  -- Comparação controlada: Política Aleatória vs. Política Convergida (ε = 0)
  let (!randRev, !randSeats) = evaluatePolicy envCfg initWeights 1.0 500 (mkStdGen 100)
      (!optRev, !optSeats)   = evaluatePolicy envCfg finalWeights 0.0 500 (mkStdGen 200)
      !gainPct               = ((optRev - randRev) / randRev) * 100.0

  putStrLn "\n2. BENCHMARK DE DESEMPENHO (500 VOOS DE TESTE FORA DA AMOSTRA)"
  putStrLn "----------------------------------------------------------------------"
  printf "  Politica Aleatoria (Baseline) : R$ %10.2f | Ocupacao: %5.1f%%\n" randRev randSeats
  printf "  Politica Linear Q-Learning    : R$ %10.2f | Ocupacao: %5.1f%%\n" optRev optSeats
  printf "  Ganho de Receita Obtido       : %+.2f%%\n" gainPct

  -- Referencias: regras fixas avaliadas nos mesmos 500 voos de teste da politica aprendida
  let rules :: [(String, FlightEnv -> Action)]
      rules =
        [ ("Sempre Promocional (R$ 300)", const PrecoPromocional)
        , ("Sempre Padrao (R$ 550)", const PrecoPadrao)
        , ("Sempre Premium (R$ 900)", const PrecoPremium)
        , ("Padrao ate faltarem 15 dias, depois Premium"
          , \env -> if envDaysLeft env > 15 then PrecoPadrao else PrecoPremium)
        ]

  putStrLn "\n3. REFERENCIAS: REGRAS DE PRECO FIXAS (MESMOS 500 VOOS DE TESTE)"
  putStrLn "----------------------------------------------------------------------"
  mapM_ (\(name, rule) ->
    let (!rev, !occ) = evaluateRule envCfg rule 500 (mkStdGen 200)
    in printf "  %-44s : R$ %10.2f | Ocupacao: %5.1f%%\n" name rev occ
    ) rules

  putStrLn "\n4. VETOR DE PESOS FINAIS APRENDIDOS (w)"
  putStrLn "----------------------------------------------------------------------"
  putStr (formatWeightsReport finalWeights)

  let csvFile = "curva_aprendizado.csv"
  exportLearningCurveCSV csvFile history
  putStrLn "\n----------------------------------------------------------------------"
  printf "Arquivo '%s' exportado com sucesso (%d registros).\n" csvFile (length history)
  putStrLn "======================================================================"
