{-# LANGUAGE BangPatterns #-}

module Environment
  ( FlightEnv(..)
  , initFlight
  , toState
  , stepEnv
  ) where

import System.Random (StdGen, randomR)
import Types

-- | Representação interna exata do estado do voo em um dia específico.
data FlightEnv = FlightEnv
  { envSeatsLeft   :: !Int    -- ^ Assentos ainda disponíveis
  , envDaysLeft    :: !Int    -- ^ Dias restantes até a decolagem
  , envLastDemand  :: !Double -- ^ Índice de demanda observado no dia anterior
  , envConfig      :: !EnvConfig
  } deriving (Show, Eq)

-- | Inicializa um novo episódio de vendas (voo vazio no dia T).
initFlight :: EnvConfig -> FlightEnv
initFlight cfg = FlightEnv
  { envSeatsLeft  = cfgTotalSeats cfg
  , envDaysLeft   = cfgTotalDays cfg
  , envLastDemand = 0.65 -- Demanda inicial moderada
  , envConfig     = cfg
  }

-- | Converte o estado interno discreto/misto no vetor de estado contínuo observado pelo agente.
toState :: FlightEnv -> State
toState env =
  let !totalS = fromIntegral (cfgTotalSeats (envConfig env))
      !totalD = fromIntegral (cfgTotalDays (envConfig env))
      !sRatio = fromIntegral (envSeatsLeft env) / totalS
      !tRatio = fromIntegral (envDaysLeft env) / totalD
  in State
       { stSeatsRatio  = sRatio
       , stTimeRatio   = tRatio
       , stDemandIndex = envLastDemand env
       }

-- | Gera uma amostra aproximada da distribuição Normal Padrão N(0, 1) usando
-- o Teorema Central do Limite (soma de 12 uniformes em [0,1] menos 6).
-- Mantém o código 100% puro e livre de dependências externas.
sampleStandardNormal :: StdGen -> (Double, StdGen)
sampleStandardNormal gen0 = go 12 0.0 gen0
  where
    go :: Int -> Double -> StdGen -> (Double, StdGen)
    go 0 !acc !g = (acc - 6.0, g)
    go !n !acc !g =
      let (!u, !g') = randomR (0.0, 1.0) g
      in go (n - 1) (acc + u) g'

-- | Executa um passo diário no ambiente de precificação dinâmica.
-- Retorna: (Próximo Ambiente, Recompensa Diária, Flag Terminal, Novo Gerador Aleatório).
stepEnv :: FlightEnv -> Action -> StdGen -> (FlightEnv, Double, Bool, StdGen)
stepEnv env action gen0
  | envDaysLeft env <= 0 || envSeatsLeft env <= 0 =
      (env, 0.0, True, gen0)
  | otherwise =
      let !cfg       = envConfig env
          !totalD    = fromIntegral (cfgTotalDays cfg)
          !daysLeft  = envDaysLeft env
          !seatsLeft = envSeatsLeft env
          !tRatio    = fromIntegral daysLeft / totalD -- 1.0 (longe) -> 0.0 (perto do voo)

          -- 1. Dinâmica da procura base: aumenta conforme se aproxima da data do voo
          -- (passageiros corporativos de última hora) + autocorrelação + choque estocástico.
          (!noise, !gen1) = sampleStandardNormal gen0
          !urgencyBoost   = 0.45 * (1.0 - tRatio)
          !rawDemand      = 0.45 * envLastDemand env + 0.35 + urgencyBoost + 0.12 * noise
          !marketDemand   = max 0.1 (min 1.5 rawDemand)

          -- 2. Elasticidade-preço da demanda:
          -- Perto do voo (tRatio baixo), passageiros são menos sensíveis a preços altos.
          !price          = actionPrice action
          !refPrice       = actionPrice PrecoPadrao
          !elasticity     = 0.65 + 0.85 * tRatio -- Maior elasticidade longe do voo; menor perto do voo
          !priceFactor    = (refPrice / price) ** elasticity

          -- 3. Cálculo dos assentos vendidos no dia (limitado pelo estoque disponível)
          !baseDailyRate  = (fromIntegral (cfgTotalSeats cfg) / totalD) * 1.15
          !expectedSales  = baseDailyRate * marketDemand * priceFactor
          !soldToday      = min seatsLeft (max 0 (round expectedSales))

          -- 4. Receita diária obtida (Recompensa R_t)
          !reward         = fromIntegral soldToday * price

          -- 5. Atualização do ambiente para o dia seguinte
          !nextSeats      = seatsLeft - soldToday
          !nextDays       = daysLeft - 1
          !isTerminal     = nextDays <= 0 || nextSeats <= 0
          !nextEnv        = env
            { envSeatsLeft  = nextSeats
            , envDaysLeft   = nextDays
            , envLastDemand = marketDemand
            }
      in (nextEnv, reward, isTerminal, gen1)
