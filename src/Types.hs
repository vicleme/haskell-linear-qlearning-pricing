{-# LANGUAGE StrictData #-}

module Types
  ( Action(..)
  , allActions
  , actionIndex
  , actionPrice
  , State(..)
  , FeatureVector
  , WeightVector
  , HyperParams(..)
  , EnvConfig(..)
  , EpisodeStats(..)
  ) where

-- | Ações discretas de precificação disponíveis para a companhia aérea.
data Action
  = PrecoPromocional  -- ^ Tarifa reduzida para estimular demanda e escoar assentos
  | PrecoPadrao       -- ^ Tarifa base de equilíbrio
  | PrecoPremium      -- ^ Tarifa elevada para capturar excedente em alta demanda/escassez
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | Lista canônica de todas as ações possíveis.
allActions :: [Action]
allActions = [minBound .. maxBound]

-- | Índice inteiro da ação (0, 1, 2) usado para mapeamento no vetor de características.
actionIndex :: Action -> Int
actionIndex PrecoPromocional = 0
actionIndex PrecoPadrao      = 1
actionIndex PrecoPremium     = 2

-- | Preço unitário da passagem (em R$) associado a cada ação.
actionPrice :: Action -> Double
actionPrice PrecoPromocional = 300.0
actionPrice PrecoPadrao      = 550.0
actionPrice PrecoPremium     = 900.0

-- | Estado contínuo do ambiente de Revenue Management.
-- Todas as variáveis são normalizadas ou contínuas, inviabilizando Q-Learning tabular.
data State = State
  { stSeatsRatio  :: Double -- ^ Percentual de assentos disponíveis [0.0, 1.0]
  , stTimeRatio   :: Double -- ^ Tempo restante normalizado até o voo [0.0, 1.0] (1.0 = início, 0.0 = decolagem)
  , stDemandIndex :: Double -- ^ Índice contínuo da demanda recente observada [0.0, 1.5+]
  } deriving (Show, Eq)

-- | Vetor de características φ(s, a) ∈ ℝ^d.
type FeatureVector = [Double]

-- | Vetor de pesos aprendidos w ∈ ℝ^d.
type WeightVector = [Double]

-- | Hiperparâmetros do algoritmo Linear Q-Learning.
data HyperParams = HyperParams
  { hpAlpha       :: Double -- ^ Taxa de aprendizado (step-size α)
  , hpGamma       :: Double -- ^ Fator de desconto temporal (γ)
  , hpEpsilonInit :: Double -- ^ Taxa inicial de exploração (ε_0)
  , hpEpsilonMin  :: Double -- ^ Taxa mínima de exploração (ε_min)
  , hpEpsilonDec  :: Double -- ^ Fator multiplicativo de decaimento de ε por episódio
  , hpNumEpisodes :: Int    -- ^ Total de voos simulados (episódios de treinamento)
  } deriving (Show, Eq)

-- | Configurações estruturais da simulação do voo.
data EnvConfig = EnvConfig
  { cfgTotalSeats :: Int -- ^ Capacidade total da aeronave (ex: 100 assentos)
  , cfgTotalDays  :: Int -- ^ Horizonte de vendas em dias até a decolagem (ex: 30 dias)
  } deriving (Show, Eq)

-- | Estatísticas consolidadas de um episódio completo (um voo).
data EpisodeStats = EpisodeStats
  { epNumber      :: Int    -- ^ Índice do episódio
  , epTotalReward :: Double -- ^ Receita total acumulada no voo (R$)
  , epSeatsSold   :: Int    -- ^ Total de assentos vendidos até a decolagem
  , epEpsilon     :: Double -- ^ Valor de ε vigente no episódio
  } deriving (Show, Eq)
